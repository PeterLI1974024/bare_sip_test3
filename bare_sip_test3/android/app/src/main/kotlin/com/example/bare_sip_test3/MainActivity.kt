package com.example.bare_sip_test3

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tutpro.baresip.Api
import com.tutpro.baresip.BaresipService

class MainActivity : FlutterActivity() {

    private var uaPtr: Long = 0L
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "baresip")
        BaresipService.eventChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                "baresip_start" -> {
                    val path = applicationContext.filesDir.absolutePath
                    Log.d("Baresip", "baresip_start path=$path")
                    val intent = Intent(this@MainActivity, BaresipService::class.java)
                    intent.action = "Start"
                    startService(intent)
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
                    val aor = call.argument<String>("aor")
                        ?: return@setMethodCallHandler result.error("ARG", "missing aor", null)
                    val authUser = call.argument<String>("authUser") ?: ""
                    val authPass = call.argument<String>("authPass") ?: ""
                    if (uaPtr == 0L) {
                        val uri = buildString {
                            append('<')
                            append(aor)
                            append('>')
                            if (authUser.isNotEmpty()) {
                                append(";auth_user=")
                                append(authUser)
                            }
                            if (authPass.isNotEmpty()) {
                                append(";auth_pass=")
                                append(authPass)
                            }
                        }
                        uaPtr = Api.ua_alloc(uri)
                        if (uaPtr == 0L) return@setMethodCallHandler result.error("UA", "ua_alloc failed", null)
                        Log.d("Baresip", "ua_alloc($uri) => $uaPtr")
                    }
                    val code = Api.ua_register(uaPtr)
                    Log.d("Baresip", "ua_register => $code")
                    result.success(code)
                }

                "call_connect" -> {
                    val target = call.argument<String>("target")
                        ?: return@setMethodCallHandler result.error("ARG", "missing target", null)
                    val code = Api.ua_connect(uaPtr, target)
                    Log.d("Baresip", "ua_connect($target) => $code")
                    result.success(code)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun started() {
        Log.d("Baresip", "native signalled baresip started")
        channel.invokeMethod("started", null)
    }
}
