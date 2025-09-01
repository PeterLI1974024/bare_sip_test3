package com.example.bare_sip_test3

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 關鍵：把你自訂的 plugin 加進 engine
        flutterEngine.plugins.add(BaresipPlugin())
    }
}
