#include <jni.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <android/log.h>
#include <re.h>
#include <baresip.h>
#include <android/log.h>
#include <aaudio/AAudio.h>


#define LOG_TAG "baresip_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static struct call *g_current_call = NULL;

struct call *get_current_call(void) {
    return g_current_call;
}

static void call_service_void_method(const char *name);



JNIEXPORT jint JNICALL
Java_com_tutpro_baresip_Api_testNative(JNIEnv *env, jclass cls, jint value) {
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "[C] testNative 被呼叫, value=%d", value);
    return 120; 
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


JNIEXPORT jint JNICALL
Java_com_tutpro_baresip_Api_ua_1connect(JNIEnv *env, jclass cls, jlong uap, jstring jPeer) {
    (void)cls;

    struct ua *ua = (struct ua *)(intptr_t)uap;
    if (!ua || !jPeer) return -1;

    const char *peer = (*env)->GetStringUTFChars(env, jPeer, 0);
    int err = 0;

    struct call *call = NULL;

    // 呼叫 baresip 提供的 API 建立 outgoing call
    err = ua_connect(ua, &call, NULL, peer, VIDMODE_ON);

    (*env)->ReleaseStringUTFChars(env, jPeer, peer);

    if (err) {
        warning("JNI ua_connect: failed with err=%d\n", err);
        return -1;
    }

    return 0;  // success
}

static JavaVM *g_vm = NULL;
static jobject g_service = NULL; // GlobalRef of BaresipService instance

void log_loaded_modules(void) {
    struct le *le;
    for (le = list_head(mod_list()); le; le = le->next) {
        struct mod *mod = le->data;
        const struct mod_export *me = mod_export(mod);

        if (me) {
            LOGI("Loaded module: %s (type=%s)", me->name, me->type);
        } else {
            LOGI("Loaded module: <unknown>");
        }
    }
}


static void event_handler(enum bevent_ev ev, struct bevent *event, void *arg) {
    (void)arg;
    const char *prm = bevent_get_text(event);
    struct ua *ua = bevent_get_ua(event);
    struct call *call = bevent_get_call(event);
    const struct sip_msg *msg = bevent_get_msg(event);

    __android_log_print(ANDROID_LOG_INFO, "JNI_TEST",
                        "bevent: ev=%d, prm=%s, ua=%p, call=%p",
                        ev, prm ? prm : "", ua, call);

    switch (ev) {
        case BEVENT_REGISTER_OK:
            LOGI("REGISTER OK (%s)", prm ? prm : "");
            break;

        case BEVENT_REGISTER_FAIL:
            LOGI("REGISTER FAIL (%s)", prm ? prm : "");
            break;

      case BEVENT_SIPSESS_CONN: {
    // 用 msg 嘗試找對應 UA
    ua = uag_find_msg(msg);

    // 還沒有正式 call，用 msg pointer 暫存
    call = (struct call *)msg;

    if (msg) {
        char from_buf[256], to_buf[256], ruri_buf[256], callid_buf[256];

        pl_strcpy(&msg->from.auri, from_buf, sizeof(from_buf));
        pl_strcpy(&msg->to.auri,   to_buf,   sizeof(to_buf));
        pl_strcpy(&msg->ruri,      ruri_buf, sizeof(ruri_buf));
        pl_strcpy(&msg->callid,    callid_buf, sizeof(callid_buf));

        LOGI("📡 SIPSESS_CONN -------------------");
        LOGI("👉 prm     : %s", prm ? prm : "");
        LOGI("👉 UA ptr  : %p", ua);
        LOGI("👉 Call ptr: %p", call);
        LOGI("👉 From    : %s", from_buf);
        LOGI("👉 To      : %s", to_buf);
        LOGI("👉 Req-URI : %s", ruri_buf);
        LOGI("👉 Call-ID : %s", callid_buf);
        LOGI("------------------------------------");
    } else {
        LOGI("📡 SIPSESS_CONN: prm=%s, ua=%p, call=%p (msg=NULL)",
             prm ? prm : "", ua, call);
    }
    break;
}


        case BEVENT_CALL_INCOMING:
            LOGI("📞 收到來電: %s", prm ? prm : "");
            g_current_call = call;   // 暫存 call pointer
            call_service_void_method("onIncomingCall");
            break;

        case BEVENT_CALL_OUTGOING:
            LOGI("撥號出去: %s", prm ? prm : "");
            break;

        case BEVENT_CALL_RINGING:
            LOGI("對方響鈴: %s", prm ? prm : "");
            break;

        case BEVENT_CALL_ANSWERED:
            LOGI("通話接通: %s", prm ? prm : "");
            break;

        case BEVENT_CALL_ESTABLISHED: {
            LOGI("通話已建立，準備啟動音訊, call=%p", call);
            g_current_call = call;

            if (!call) {
                LOGE("call=NULL, 無法啟動音訊");
                break;
            }

            struct audio *a = call_audio(call);
            const struct aucodec *ac_tx = audio_codec(a, true);
            const struct aucodec *ac_rx = audio_codec(a, false);

            if (ac_tx && ac_rx) {
                LOGI("Negotiated codec: TX=%s/%u/%u, RX=%s/%u/%u",
                     ac_tx->name, ac_tx->srate, ac_tx->ch,
                     ac_rx->name, ac_rx->srate, ac_rx->ch);
            } else {
                LOGE("No codec negotiated!");
            }

            if (a && !audio_started(a)) {
                LOGI("呼叫 audio_update() 來開啟音訊 (mic+speaker)");
                audio_update(a);
            } else {
                LOGI("音訊已經在跑，無需再啟動");
            }
            break;
        }

        case BEVENT_CALL_CLOSED:
            LOGI("通話結束: %s", prm ? prm : "");
            g_current_call = NULL;
            break;

        default:
            break;
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
  if (err) {
    LOGE("libre_init failed (%d)", err);
    goto out;
} else {
    LOGI("libre_init 成功");
}
  err = conf_configure();
    if (err) {
        LOGI("conf_configure() failed: (%d)\n", err);
        goto out;
    }else{
        LOGI("conf_configure() 成功");
    }


    err = baresip_init(conf_config());
  if (err) {
    LOGE("baresip_init failed (%d)", err);
    goto out_close_re;
} else {
    LOGI("baresip_init 成功");
}



err = conf_modules();
if (err) {
    LOGE("conf_modules() failed (%d)", err);
    goto out_close_baresip;
}else{
    LOGI("conf_modules() 成功");
        log_loaded_modules();  // 列印所有載入的模組
}
    err = ua_init(a->software ? a->software : "baresip", true, true, true);
   if (err) {
    LOGE("ua_init failed (%d)", err);
    goto out_close_baresip;
} else {
    LOGI("ua_init 成功");
}

LOGI("即將開啟 SIP trace...");
uag_enable_sip_trace(true);
LOGI("SIP trace 已經打開");


    err = bevent_register(event_handler, NULL);
    call_service_void_method("started");


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

JNIEXPORT jlong JNICALL
Java_com_tutpro_baresip_Api_getCurrentCall(JNIEnv *env, jclass cls) {
    (void)env; (void)cls;
    return (jlong)(intptr_t)get_current_call();
}


JNIEXPORT void JNICALL
Java_com_tutpro_baresip_Api_call_1hangup(JNIEnv *env, jclass cls, jlong callPtr) {
    (void)env; (void)cls;
    struct call *call = (struct call *)(intptr_t)callPtr;
    if (!call) {
        LOGE("call_hangup: call=NULL");
        return;
    }

    LOGI("call_hangup: 掛斷通話 call=%p", call);

    re_thread_enter();
    call_hangup(call, 0, NULL);   // 0 = 正常掛斷，NULL = 沒有理由字串
    re_thread_leave();
}

JNIEXPORT jint JNICALL
Java_com_tutpro_baresip_Api_call_1answer(JNIEnv *env, jclass cls, jlong callPtr, jint videoMode) {
    (void)env; (void)cls;
    struct call *call = (struct call *)(intptr_t)callPtr;
    if (!call) {
        LOGE("call_answer: call=NULL");
        return -1;
    }

    LOGI("call_answer: 接聽通話 call=%p, videoMode=%d", call, videoMode);

    re_thread_enter();
    int err = call_answer(call, 200, (enum vidmode)videoMode);  // 200=OK
    re_thread_leave();

    return err;
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

