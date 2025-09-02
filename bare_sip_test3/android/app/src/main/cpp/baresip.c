#include <jni.h>
#include <stdbool.h>
#include <re.h>
#include <rem.h>
#include <baresip.h>
#include <android/log.h>

#define LOG_TAG "baresip_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

JNIEXPORT void JNICALL
Java_com_tutpro_baresip_BaresipService_baresipStart(
        JNIEnv *env, jobject thiz,
        jstring jPath, jstring jAddrs,
        jint jLogLevel, jstring jSoftware) {

    const char *path = (*env)->GetStringUTFChars(env, jPath, 0);
    const char *software = (*env)->GetStringUTFChars(env, jSoftware, 0);

    LOGI("baresipStart: path=%s, software=%s", path, software);

    int err = libre_init();
    if (err) {
        LOGE("libre_init failed (%d)", err);
        goto out;
    }

    err = baresip_init(conf_config());
    if (err) {
        LOGE("baresip_init failed (%d)", err);
        goto out;
    }

    err = ua_init(software, true, true, true);  // use <stdbool.h>
    if (err) {
        LOGE("ua_init failed (%d)", err);
        goto out;
    }

    LOGI("baresip main loop start...");
    re_main(NULL);

out:
    ua_close();
    baresip_close();
    libre_close();

    (*env)->ReleaseStringUTFChars(env, jPath, path);
    (*env)->ReleaseStringUTFChars(env, jSoftware, software);
}
