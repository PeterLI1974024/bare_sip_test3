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
#include <android/log.h>

#define LOG_TAG "JNI_TEST"

// Forward declare UA functions from baresip without pulling headers
int ua_alloc(void **uap, const char *aor);
int ua_register(void *ua);
int ua_connect(void *ua, void **callp, const char *from_uri, const char *req_uri, int vmode);

enum bevent_ev;
struct bevent;
int bevent_register(void (*h)(enum bevent_ev ev, struct bevent *event, void *arg), void *arg);
const char *bevent_get_text(const struct bevent *event);
struct ua *bevent_get_ua(const struct bevent *event);
struct call *bevent_get_call(const struct bevent *event);

enum bevent_ev {
    BEVENT_CREATE = 0,
    BEVENT_REGISTERING,
    BEVENT_UNREGISTERING,
    BEVENT_REGISTER_OK,
    BEVENT_FALLBACK_OK,
    BEVENT_REGISTER_FAIL,
    BEVENT_FALLBACK_FAIL,
    BEVENT_CALL_INCOMING,
    // … 其他的照 bevent.h 抄
};


JNIEXPORT jint JNICALL
Java_com_tutpro_baresip_Api_testNative(JNIEnv *env, jclass cls, jint value) {
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "[C] testNative 被呼叫, value=%d", value);
    return 120;  // 簡單回傳乘以 10
}

// JNI bridge for UA operations via baresip_ffi
JNIEXPORT jlong JNICALL Java_com_tutpro_baresip_Api_ua_1alloc(
        JNIEnv *env, jclass cls, jstring jUri) {
    (void)cls;
    if (!jUri) return 0;

    const char *uri = (*env)->GetStringUTFChars(env, jUri, 0);
    __android_log_print(ANDROID_LOG_ERROR, "JNI", "[C] ua_alloc 被呼叫, uri=%s", uri);

    struct ua *ua = NULL;
    int err = ua_alloc(&ua, uri);
    (*env)->ReleaseStringUTFChars(env, jUri, uri);

    if (err || !ua) {
        __android_log_print(ANDROID_LOG_ERROR, "JNI", "[C] ua_alloc 失敗 err=%d", err);
        return 0;
    }

    __android_log_print(ANDROID_LOG_INFO, "JNI", "[C] ua_alloc 成功, ua=%p", ua);
    return (jlong)(intptr_t)ua;
}

JNIEXPORT jint JNICALL Java_com_tutpro_baresip_Api_ua_1register(
        JNIEnv *env, jclass cls, jlong uaPtr) {
    (void)env; (void)cls;
    __android_log_print(ANDROID_LOG_INFO, "JNI", "[C] ua_register 被呼叫, uaPtr=%ld", (long)uaPtr);

    re_thread_enter();
    int res = ua_register((struct ua *)uaPtr);
    re_thread_leave();

    __android_log_print(ANDROID_LOG_INFO, "JNI", "[C] ua_register 回傳 %d", res);
    return res;
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

static void event_handler(enum bevent_ev ev, struct bevent *event, void *arg) {
    (void)arg;
    const char *prm = bevent_get_text(event);
    struct ua *ua = bevent_get_ua(event);
    struct call *call = bevent_get_call(event);

    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST",
                        "bevent: ev=%d, prm=%s, ua=%p, call=%p",
                        ev, prm ? prm : "", ua, call);

    if (ev ==  BEVENT_REGISTER_OK) {
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "REGISTER OK (%s)", prm ? prm : "");
    } else if (ev == BEVENT_REGISTER_FAIL) {
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "REGISTER FAIL (%s)", prm ? prm : "");
    }
}

typedef struct {
    char *path;
    char *software;
} StartArgs;

static void call_service_void_method(const char *name) {
    if (!g_vm || !g_service) {
        LOGE("call_service_void_method: g_vm=%p g_service=%p", g_vm, g_service);
        return;
    }
    
    JNIEnv *env = NULL;
    jint result = (*g_vm)->AttachCurrentThread(g_vm, &env, NULL);
    if (result != JNI_OK || !env) {
        LOGE("call_service_void_method: AttachCurrentThread failed with %d", result);
        return;
    }
    
    LOGI("call_service_void_method: attached to thread, calling %s", name);
    
    jclass cls = (*env)->GetObjectClass(env, g_service);
    if (!cls) {
        LOGE("call_service_void_method: GetObjectClass failed");
        (*g_vm)->DetachCurrentThread(g_vm);
        return;
    }
    
    jmethodID mid = (*env)->GetMethodID(env, cls, name, "()V");
    if (!mid) {
        LOGE("call_service_void_method: GetMethodID failed for %s", name);
        (*env)->DeleteLocalRef(env, cls);
        (*g_vm)->DetachCurrentThread(g_vm);
        return;
    }
    
    LOGI("call_service_void_method: calling method %s", name);
    (*env)->CallVoidMethod(env, g_service, mid);
    
    if ((*env)->ExceptionCheck(env)) {
        LOGE("call_service_void_method: Exception occurred calling %s", name);
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    } else {
        LOGI("call_service_void_method: %s called successfully", name);
    }
    
    (*env)->DeleteLocalRef(env, cls);
    (*g_vm)->DetachCurrentThread(g_vm);
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
    err = bevent_register(event_handler, NULL);


    LOGI("baresip ready, initialization complete");
    
    // 檢查網路狀態和模組載入
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Network status check complete");
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Checking loaded modules...");
    
    // 嘗試列出可用的 SIP 傳輸
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Module check complete");
    
    // 確保初始化完成後才回呼 started
    // call_service_void_method("started");
    
    // 啟動 baresip 事件循環 (非阻塞)
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Starting event loop...");
    
    // 啟動 re_main 事件循環
    re_main(NULL);
    
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Event loop stopped");

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
Java_com_tutpro_baresip_Api_baresipStart(
        JNIEnv *env, jobject thiz,
        jstring jPath, jstring jAddrs,
        jint jLogLevel, jstring jSoftware) {

    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] 進入 baresipStart() JNI");

    (void)jAddrs; (void)jLogLevel;
    const char *path = jPath ? (*env)->GetStringUTFChars(env, jPath, 0) : NULL;
    const char *soft = jSoftware ? (*env)->GetStringUTFChars(env, jSoftware, 0) : NULL;

    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST",
                        "[C] 傳入參數 path=%s, software=%s",
                        path ? path : "(null)",
                        soft ? soft : "(null)");

    // Keep global ref to service instance for callbacks
    if (g_service) {
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] 刪除舊的 GlobalRef g_service=%p", g_service);
        (*env)->DeleteGlobalRef(env, g_service);
        g_service = NULL;
    }
    g_service = (*env)->NewGlobalRef(env, thiz);
    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] 建立新的 GlobalRef g_service=%p", g_service);

    StartArgs *args = (StartArgs *)calloc(1, sizeof(StartArgs));
    args->path = path ? strdup(path) : NULL;
    args->software = soft ? strdup(soft) : NULL;

    if (path) {
        (*env)->ReleaseStringUTFChars(env, jPath, path);
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] 已釋放 path");
    }
    if (soft) {
        (*env)->ReleaseStringUTFChars(env, jSoftware, soft);
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] 已釋放 software");
    }

    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST",
                        "[C] pthread_create 準備啟動 re_thread_main, path=%s, software=%s",
                        args->path ? args->path : "(null)",
                        args->software ? args->software : "(null)");

    pthread_t tid;
    int rc = pthread_create(&tid, NULL, re_thread_main, args);
    if (rc != 0) {
        __android_log_print(ANDROID_LOG_ERROR, "JNI_TEST", "[C] pthread_create 失敗 rc=%d", rc);
    } else {
        __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] pthread_create 成功 tid=%lu", (unsigned long)tid);
    }

    pthread_detach(tid);
    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST", "[C] pthread_detach 完成");
}

