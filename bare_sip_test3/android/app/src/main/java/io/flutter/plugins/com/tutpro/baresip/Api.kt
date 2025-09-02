package com.tutpro.baresip

object Api {
    init {
        System.loadLibrary("baresip") // SIP 核心
        System.loadLibrary("baresip_ffi") // 我們的 JNI 橋接
    }

    // === UA 操作 ===
    external fun ua_alloc(uri: String): Long
    external fun ua_register(uap: Long): Int
    external fun ua_connect(uap: Long, peerUri: String): Int
    external fun ua_hangup(uap: Long, callp: Long, code: Int, reason: String)
}
