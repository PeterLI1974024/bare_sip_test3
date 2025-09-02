package com.tutpro.baresip

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.annotation.Keep
import io.flutter.plugin.common.MethodChannel

class BaresipService : Service() {

    companion object {
        var isServiceRunning = false
        var eventChannel: MethodChannel? = null
        
        init {
            System.loadLibrary("baresip")
            System.loadLibrary("baresip_ffi")
        }
    }

    private external fun baresipStart(path: String, addrs: String, logLevel: Int, software: String)
    external fun baresipStop()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "Start" -> {
                if (!isServiceRunning) {
                    Log.d("Baresip", "Starting baresip service")
                    isServiceRunning = true
                    val filesPath = filesDir.absolutePath
                    Thread {
                        baresipStart(filesPath, "", 5, "flutter_sip")
                    }.start()
                }
            }
            "Stop" -> {
                Log.d("Baresip", "Stopping baresip service")
                baresipStop()
                isServiceRunning = false
                stopSelf()
            }
        }
        return START_STICKY
    }

    // JNI 回呼方法 - 使用 @Keep 避免混淆
    @Keep
    @Suppress("unused")
    fun started() {
        Log.d("Baresip", "native 回呼 started()")
        eventChannel?.invokeMethod("started", null)
    }

    @Keep
    @Suppress("unused")
    fun uaEvent(event: String, uap: Long, callp: Long) {
        Log.d("Baresip", "native uaEvent event=$event ua=$uap call=$callp")
        val args = mapOf("event" to event, "uap" to uap, "callp" to callp)
        eventChannel?.invokeMethod("ua_event", args)
    }

    @Keep
    @Suppress("unused")
    fun stopped(error: String) {
        Log.d("Baresip", "native stopped, error=$error")
        eventChannel?.invokeMethod("stopped", error)
        isServiceRunning = false
        stopSelf()
    }
}
