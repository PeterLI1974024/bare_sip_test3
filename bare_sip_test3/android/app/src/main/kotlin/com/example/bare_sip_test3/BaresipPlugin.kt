package com.example.bare_sip_test3

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.tutpro.baresip.Api   // 匯入剛剛的 Api.kt

class BaresipPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel : MethodChannel

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "baresip")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "ua_register" -> {
                val aor = call.argument<String>("aor") ?: return result.error("ARG", "missing aor", null)
                val authUser = call.argument<String>("authUser") ?: ""
                val authPass = call.argument<String>("authPass") ?: ""
                val ret = Api.ua_register(aor, authUser, authPass) // 呼叫 JNI
                result.success(ret)
            }
            "call_connect" -> {
                val target = call.argument<String>("target") ?: return result.error("ARG", "missing target", null)
                val ret = Api.call_connect(target) // 呼叫 JNI
                result.success(ret)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
