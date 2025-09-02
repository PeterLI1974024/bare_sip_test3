package com.example.bare_sip_test3

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.tutpro.baresip.Api
import com.tutpro.baresip.BaresipService

class BaresipPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel : MethodChannel

    private var uaPtr: Long = 0L

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "baresip")
        channel.setMethodCallHandler(this)
        // 將事件通道交給服務
        BaresipService.eventChannel = channel
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "baresip_start" -> {
                val intent = Intent(null, BaresipService::class.java)
                intent.action = "Start"
                result.success(0)
            }
            "ua_register" -> {
                val aor = call.argument<String>("aor") ?: return result.error("ARG", "missing aor", null)
                val authUser = call.argument<String>("authUser") ?: ""
                val authPass = call.argument<String>("authPass") ?: ""
                if (uaPtr == 0L) {
                    // 將密碼以 ;auth_pass 附加到 AOR（auth_user 若非空可在 params 中指定）
                    val uri = if (authPass.isNotEmpty()) "<$aor>;auth_pass=$authPass" else "<$aor>"
                    uaPtr = Api.ua_alloc(uri)
                    if (uaPtr == 0L) return result.error("UA", "ua_alloc failed", null)
                }
                val ret = Api.ua_register(uaPtr)
                result.success(ret)
            }
            "call_connect" -> {
                val target = call.argument<String>("target") ?: return result.error("ARG", "missing target", null)
                if (uaPtr == 0L) return result.error("UA", "ua not allocated", null)
                val ret = Api.ua_connect(uaPtr, target)
                result.success(ret)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
