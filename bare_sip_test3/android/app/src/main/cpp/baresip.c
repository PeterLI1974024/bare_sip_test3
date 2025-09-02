#include <jni.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <android/log.h>

// Forward declarations to avoid pulling mismatched headers
int libre_init(void);
void libre_close(void);
int baresip_init(void *cfg);
void baresip_close(void);
int ua_init(const char *software, int aumode, int vumode, int dumode);
void ua_close(void);
void re_main(void *arg);
void *conf_config(void);
int conf_path_set(const char *path);

#define LOG_TAG "baresip_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Forward declare UA functions from baresip without pulling headers
int ua_alloc(void **uap, const char *aor);
int ua_register(void *ua);
int ua_connect(void *ua, void **callp, const char *from_uri, const char *req_uri, int vmode);

// JNI bridge for UA operations via baresip_ffi
JNIEXPORT jlong JNICALL Java_com_tutpro_baresip_Api_ua_1alloc(JNIEnv *env, jclass cls, jstring jUri) {
    (void)cls;
    if (!jUri) return 0;
    const char *uri = (*env)->GetStringUTFChars(env, jUri, 0);
    void *ua = NULL;
    int err = ua_alloc(&ua, uri);
    (*env)->ReleaseStringUTFChars(env, jUri, uri);
    if (err || !ua) return 0;
    return (jlong)(intptr_t)ua;
}

JNIEXPORT jint JNICALL Java_com_tutpro_baresip_Api_ua_1register(JNIEnv *env, jclass cls, jlong uap) {
    (void)env; (void)cls;
    void *ua = (void*)(intptr_t)uap;
    if (!ua) return -1;
    return ua_register(ua);
}

JNIEXPORT jint JNICALL Java_com_tutpro_baresip_Api_ua_1connect(JNIEnv *env, jclass cls, jlong uap, jstring jPeer) {
    (void)cls;
    void *ua = (void*)(intptr_t)uap;
    if (!ua || !jPeer) return -1;
    const char *peer = (*env)->GetStringUTFChars(env, jPeer, 0);
    void *call = NULL;
    int err = ua_connect(ua, &call, NULL, peer, 1);
    (*env)->ReleaseStringUTFChars(env, jPeer, peer);
    return err;
}

static JavaVM *g_vm = NULL;
static jobject g_service = NULL; // GlobalRef of BaresipService instance

typedef struct {
    char *path;
    char *software;
} StartArgs;

static void call_service_void_method(const char *name) {
    if (!g_vm || !g_service) return;
    JNIEnv *env = NULL;
    if ((*g_vm)->AttachCurrentThread(g_vm, &env, NULL) != 0 || !env) return;
    jclass cls = (*env)->GetObjectClass(env, g_service);
    if (!cls) return;
    jmethodID mid = (*env)->GetMethodID(env, cls, name, "()V");
    if (mid) {
        (*env)->CallVoidMethod(env, g_service, mid);
    }
}

static void *re_thread_main(void *arg) {
    StartArgs *a = (StartArgs *)arg;
    LOGI("native thread starting, path=%s, software=%s", a->path, a->software);

    if (a->path) {
        (void)conf_path_set(a->path);
    }

    // 提升日誌輸出，便於排查啟動卡住
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "conf_path set to: %s", a->path ? a->path : "(null)");

    int err = libre_init();
    if (err) { LOGE("libre_init failed (%d)", err); goto out; }

    err = baresip_init(conf_config());
    if (err) { LOGE("baresip_init failed (%d)", err); goto out_close_re; }

    err = ua_init(a->software ? a->software : "baresip", 1, 1, 1);
    if (err) { LOGE("ua_init failed (%d)", err); goto out_close_baresip; }

    // Signal started to Kotlin service
    call_service_void_method("started");

    LOGI("baresip ready, not starting main loop to avoid blocking...");
    // 不啟動 re_main 避免阻塞，baresip 初始化完成即可使用

    call_service_void_method("stopped");

    ua_close();
out_close_baresip:
    baresip_close();
out_close_re:
    libre_close();
out:
    free(a->path);
    free(a->software);
    free(a);
    return NULL;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    g_vm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL
Java_com_tutpro_baresip_BaresipService_baresipStart(
        JNIEnv *env, jobject thiz,
        jstring jPath, jstring jAddrs,
        jint jLogLevel, jstring jSoftware) {
    (void)jAddrs; (void)jLogLevel;
    const char *path = jPath ? (*env)->GetStringUTFChars(env, jPath, 0) : NULL;
    const char *soft = jSoftware ? (*env)->GetStringUTFChars(env, jSoftware, 0) : NULL;

    // Keep global ref to service instance for callbacks
    if (g_service) {
        (*env)->DeleteGlobalRef(env, g_service);
        g_service = NULL;
    }
    g_service = (*env)->NewGlobalRef(env, thiz);

    StartArgs *args = (StartArgs *)calloc(1, sizeof(StartArgs));
    args->path = path ? strdup(path) : NULL;
    args->software = soft ? strdup(soft) : NULL;

    if (path) (*env)->ReleaseStringUTFChars(env, jPath, path);
    if (soft) (*env)->ReleaseStringUTFChars(env, jSoftware, soft);

    pthread_t tid;
    pthread_create(&tid, NULL, re_thread_main, args);
    pthread_detach(tid);
}
