package com.tutpro.baresip

object Api {
    init {
        System.loadLibrary("baresip") // 載入 libbaresip.so
    }

    // 對應 JNI 符號 Java_com_tutpro_baresip_Api_ua_register
    external fun ua_register(aor: String, authUser: String, authPass: String): Int

    // 對應 JNI 符號 Java_com_tutpro_baresip_Api_call_connect
    external fun call_connect(target: String): Int
}
