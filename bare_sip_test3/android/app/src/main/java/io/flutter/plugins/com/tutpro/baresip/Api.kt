package com.tutpro.baresip

object Api {
    init {
        System.loadLibrary("baresip") // 載入 libbaresip.so
    }

    // === UA 操作 ===
    external fun ua_alloc(uri: String): Long
    external fun ua_register(uap: Long): Int
    external fun ua_unregister(uap: Long)
    external fun ua_isregistered(uap: Long): Boolean
    external fun ua_destroy(uap: Long)

    // === 通話操作 ===
    external fun ua_call_alloc(uap: Long, xcallp: Long, video: Int): Long
    external fun call_connect(callp: Long, peerUri: String): Int
external fun ua_hangup(uap: Long, callp: Long, code: Int, reason: String)


    // === 測試用 ===
    external fun audio_codecs(): String
    external fun video_codecs(): String
}
