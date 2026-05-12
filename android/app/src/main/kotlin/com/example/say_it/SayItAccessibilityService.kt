package com.example.say_it

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SayItAccessibilityService : AccessibilityService() {

    companion object {
        var instance: SayItAccessibilityService? = null
            private set
    }

    private var registeredEngine: FlutterEngine? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("SayItAccessibility", "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            val engine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("myCachedEngine")
            if (engine != null && engine != registeredEngine) {
                Log.d("SayItAccessibility", "New Overlay Engine found! Registering MethodChannel.")
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.say_it/accessibility")
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isAccessibilityEnabled" -> result.success(true)
                        "extractScreenText" -> result.success(extractScreenText())
                        "injectText" -> {
                            val text = call.argument<String>("text")
                            if (text != null) {
                                result.success(injectTextIntoActiveField(text))
                            } else {
                                result.error("BAD_ARGS", "Missing text", null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
                registeredEngine = engine
            }
        } catch (e: Exception) {
            Log.e("SayItAccessibility", "Error binding to engine: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d("SayItAccessibility", "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        registeredEngine = null
        Log.d("SayItAccessibility", "Accessibility Service Destroyed")
    }

    fun extractScreenText(): String {
        val rootNode = rootInActiveWindow ?: return "NO_ROOT_NODE"
        val stringBuilder = java.lang.StringBuilder()
        traverseNodeForText(rootNode, stringBuilder)
        rootNode.recycle()
        return stringBuilder.toString()
    }

    fun injectTextIntoActiveField(textToInject: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val editableNode = findEditableNode(rootNode)
        
        var success = false
        if (editableNode != null) {
            val arguments = Bundle()
            arguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, 
                textToInject
            )
            success = editableNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            editableNode.recycle()
        }
        
        rootNode.recycle()
        return success
    }

    private fun traverseNodeForText(node: AccessibilityNodeInfo, builder: java.lang.StringBuilder) {
        if (node.text != null && node.text.toString().isNotBlank()) {
            builder.append(node.text).append("\n")
        } else if (node.contentDescription != null && node.contentDescription.toString().isNotBlank()) {
            builder.append(node.contentDescription).append("\n")
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                traverseNodeForText(child, builder)
                child.recycle()
            }
        }
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable && node.isEnabled) {
            return AccessibilityNodeInfo.obtain(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val editable = findEditableNode(child)
                child.recycle()
                if (editable != null) {
                    return editable
                }
            }
        }
        return null
    }
}
