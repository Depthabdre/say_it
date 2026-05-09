package com.example.say_it

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.say_it/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    val isEnabled = SayItAccessibilityService.instance != null
                    result.success(isEnabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "extractScreenText" -> {
                    val service = SayItAccessibilityService.instance
                    if (service != null) {
                        val text = service.extractScreenText()
                        result.success(text)
                    } else {
                        result.error("UNAVAILABLE", "Accessibility service not running.", null)
                    }
                }
                "injectText" -> {
                    val textToInject = call.argument<String>("text")
                    val service = SayItAccessibilityService.instance
                    if (service != null && textToInject != null) {
                        val success = service.injectTextIntoActiveField(textToInject)
                        result.success(success)
                    } else {
                        result.error("UNAVAILABLE", "Service not running or text missing.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
