package com.example.say_it

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SayItPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.say_it/accessibility")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAccessibilityEnabled" -> {
                val isEnabled = SayItAccessibilityService.instance != null
                result.success(isEnabled)
            }
            "openAccessibilitySettings" -> {
                val currentContext = context
                if (currentContext != null) {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    currentContext.startActivity(intent)
                    result.success(true)
                } else {
                    result.error("NO_CONTEXT", "Context is null", null)
                }
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
