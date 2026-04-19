package com.moodgenie.app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.ZoneId

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moodgenie/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTimezone" -> result.success(ZoneId.systemDefault().id)
                else -> result.notImplemented()
            }
        }
    }
}
