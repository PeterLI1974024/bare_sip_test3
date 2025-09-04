package com.tutpro.baresip

object Api {
    init {
        System.loadLibrary("baresip")
        System.loadLibrary("baresip_ffi")
    }
    external fun ua_alloc(uri: String): Long
    external fun ua_register(uap: Long): Int
    external fun ua_connect(uap: Long, peerUri: String): Int

    // 新增：開啟 SIP 訊息追蹤
    external fun uag_enable_sip_trace(on: Boolean)
    external fun testNative(value: Int): Int
    external fun baresipStart(path: String, addrs: String, logLevel: Int, software: String)


}

