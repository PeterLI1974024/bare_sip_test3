package com.example.bare_sip_test3

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tutpro.baresip.Api
import com.tutpro.baresip.BaresipService
import java.io.File
import java.io.InputStream



class MainActivity : FlutterActivity() {

    private var uaPtr: Long = 0L
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    copyConfigFromAssets(this)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "baresip")
        BaresipService.eventChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
"baresip_start" -> {
    val intent = Intent(applicationContext, BaresipService::class.java).apply {
        action = "Start"
    }
    applicationContext.startService(intent)

    // 開啟 SIP trace（這個可以留著）
    try { Api.uag_enable_sip_trace(true) } catch (_: Throwable) {}

    result.success(0)
}



                "ua_alloc" -> {
                    val aor = call.argument<String>("aor")
                        ?: return@setMethodCallHandler result.error("ARG", "missing aor", null)
                    uaPtr = Api.ua_alloc(aor)
                    Log.d("Baresip", "ua_alloc($aor) => $uaPtr")
                    result.success(uaPtr)
                }

"ua_register" -> {
    Log.d("Baresip", "[Kotlin] 進入 ua_register handler")

    val user = call.argument<String>("user") ?: return@setMethodCallHandler result.error("ARG", "missing user", null)
    val domain = call.argument<String>("domain") ?: return@setMethodCallHandler result.error("ARG", "missing domain", null)
    val proxy = call.argument<String>("proxy") ?: "175.99.74.33:5060"
    val authUser = call.argument<String>("authUser") ?: ""
    val authPass = call.argument<String>("authPass") ?: ""

    Log.d("Baresip", "[Kotlin] Flutter 傳入參數 user=$user, domain=$domain, proxy=$proxy, authUser=$authUser, authPass=$authPass")

    if (uaPtr == 0L) {
        val uri = buildString {
            // 🔹 AOR 正確組成 (From/To)
            append("<sip:$user@$domain>")
            if (authUser.isNotEmpty()) {
                append(";auth_user=$authUser")
            }
            if (authPass.isNotEmpty()) {
                append(";auth_pass=$authPass")
            }
            // 🔹 Proxy 放 outbound
            append(";outbound=\"sip:$proxy;transport=tcp\"")
                append(";sipnat=outbound")

        }

        Log.d("Baresip", "[Kotlin] 準備 ua_alloc, uri=$uri")
        uaPtr = Api.ua_alloc(uri)
        Log.d("Baresip", "[Kotlin] ua_alloc 回傳 uaPtr=$uaPtr")

        if (uaPtr == 0L) {
            Log.e("Baresip", "[Kotlin] ua_alloc 失敗")
            return@setMethodCallHandler result.error("UA", "ua_alloc failed", null)
        }
    }

    Log.d("Baresip", "[Kotlin] 呼叫 ua_register, uaPtr=$uaPtr")
    val code = Api.ua_register(uaPtr)
    Log.d("Baresip", "[Kotlin] ua_register 回傳 code=$code")
    result.success(code)
}


"testNative" -> {
    val value = call.argument<Int>("value") ?: 0
    val resultCode = Api.testNative(value)
    result.success(resultCode)
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

    
private fun copyConfigFromAssets(context: android.content.Context) {
    val assetManager = context.assets
val inputStream = context.assets.open("config")
    val outFile = File(context.filesDir, "config")        // 寫到 /data/user/0/.../files/config

    if (!outFile.exists()) { // 避免覆蓋使用者改過的
        inputStream.use { input: InputStream ->
            outFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }
}

    fun started() {
        Log.d("Baresip", "native signalled baresip started")
        channel.invokeMethod("started", null)
    }
}
