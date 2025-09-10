package com.tutpro.baresip

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.annotation.Keep
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager


class BaresipService : Service() {

    companion object {
        var isServiceRunning = false
        var eventChannel: MethodChannel? = null
        
        init {
            System.loadLibrary("baresip")

        }
    }

    private external fun baresipStart(path: String, addrs: String, logLevel: Int, software: String)
    external fun baresipStop()

    override fun onBind(intent: Intent?): IBinder? = null

       override fun onCreate() {
        super.onCreate()
        Log.d("Baresip", "Service onCreate -> 設定 AudioManager")

        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        am.isSpeakerphoneOn = true   // true = 擴音，false = 聽筒
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "Start" -> {
                if (!isServiceRunning) {
                    Log.d("Baresip", "Starting baresip service")
                      val am = getSystemService(AUDIO_SERVICE) as AudioManager
                am.mode = AudioManager.MODE_IN_COMMUNICATION
                am.isSpeakerphoneOn = true   // true = 擴音，false = 聽筒
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
        // 確保在主執行緒中執行 Flutter 回呼
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventChannel?.invokeMethod("started", null)
        }
    }

    @Keep
    @Suppress("unused")
    fun uaEvent(event: String, uap: Long, callp: Long) {
        Log.d("Baresip", "native uaEvent event=$event ua=$uap call=$callp")
        val args = mapOf("event" to event, "uap" to uap, "callp" to callp)
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventChannel?.invokeMethod("ua_event", args)
        }
    }

 fun onIncomingCall() {
    val callPtr = Api.getCurrentCall() // 你需要在 native 端實作 getCurrentCall() 回傳 call 指標
    if (callPtr != 0L) {
        Log.i("BaresipService", "📞 收到來電 call=$callPtr")

        // TODO: 這裡可以彈通知或直接呼叫 UI
        // 例如自動接聽：
        Api.call_answer(callPtr, 0)  // 0 = VIDMODE_OFF (語音通話)
    }
}


    @Keep
    @Suppress("unused")
    fun stopped(error: String) {
        Log.d("Baresip", "native stopped, error=$error")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventChannel?.invokeMethod("stopped", error)
        }
        isServiceRunning = false
        stopSelf()
    }
}
