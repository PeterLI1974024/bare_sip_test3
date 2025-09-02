package com.example.bare_sip_test3

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tutpro.baresip.Api
import com.tutpro.baresip.BaresipService

class MainActivity : FlutterActivity() {

    private var uaPtr: Long = 0L
    private var callPtr: Long = 0L
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "baresip")
        BaresipService.eventChannel = channel  // ✅ 傳給 BaresipService 做事件回報

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                "baresip_start" -> {
                    val path = applicationContext.filesDir.absolutePath
                    Log.d("Baresip", "baresip_start path=$path")
                    BaresipService.baresipStart(path, "", 2, "flutter_sip")
                    result.success(0)
                }

                "ua_alloc" -> {
                    val aor = call.argument<String>("aor")
                        ?: return@setMethodCallHandler result.error("ARG", "missing aor", null)
                    uaPtr = Api.ua_alloc(aor)
                    Log.d("Baresip", "ua_alloc($aor) => $uaPtr")
                    result.success(uaPtr.toInt())
                }

                "ua_register" -> {
                    val code = Api.ua_register(uaPtr)
                    Log.d("Baresip", "ua_register => $code")
                    result.success(code)
                }

                "ua_unregister" -> {
                    Api.ua_unregister(uaPtr)
                    Log.d("Baresip", "ua_unregister")
                    result.success(0)
                }

                "call_connect" -> {
                    val target = call.argument<String>("target")
                        ?: return@setMethodCallHandler result.error("ARG", "missing target", null)
                    callPtr = Api.ua_call_alloc(uaPtr, 0L, 0)
                    val code = Api.call_connect(callPtr, target)
                    Log.d("Baresip", "call_connect($target) => $code")
                    result.success(code)
                }

                "call_hangup" -> {
                    Api.ua_hangup(uaPtr, callPtr, 200, "Normal Hangup")
                    Log.d("Baresip", "call_hangup")
                    result.success(0)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ✅ JNI 會從這裡回呼
    fun started() {
        Log.d("Baresip", "native signalled baresip started")
        // 可以透過 channel 傳回 Flutter
        channel.invokeMethod("started", null)
    }
}
