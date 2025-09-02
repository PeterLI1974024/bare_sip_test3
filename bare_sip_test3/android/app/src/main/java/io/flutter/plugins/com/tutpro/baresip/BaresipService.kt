package com.tutpro.baresip


import android.util.Log
import io.flutter.plugin.common.MethodChannel

object BaresipService {
    init { System.loadLibrary("baresip") }

    var eventChannel: MethodChannel? = null

    external fun baresipStart(path: String, addrs: String, logLevel: Int, software: String)
    external fun baresipStop()

    // ⚠️ Native 會呼叫這些
    @JvmStatic
    fun started() {
        Log.d("Baresip", "native 回呼 started()")
        eventChannel?.invokeMethod("started", null)
    }

    @JvmStatic
    fun uaEvent(ev: String, accp: Long, callp: Long) {
        Log.d("Baresip", "native uaEvent ev=$ev acc=$accp call=$callp")
        val args = mapOf("event" to ev, "accp" to accp, "callp" to callp)
        eventChannel?.invokeMethod("ua_event", args)
    }

    @JvmStatic
    fun stopped(reason: String) {
        Log.d("Baresip", "native stopped, reason=$reason")
        eventChannel?.invokeMethod("stopped", reason)
    }
}
