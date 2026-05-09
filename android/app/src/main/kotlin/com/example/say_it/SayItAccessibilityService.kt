package com.example.say_it

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class SayItAccessibilityService : AccessibilityService() {

    companion object {
        var instance: SayItAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("SayItAccessibility", "Accessibility Service Connected")
        
        try {
            // flutter_overlay_window caches the overlay engine with this tag
            val engine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("myCachedEngine")
            if (engine != null) {
                MainActivity.setupMethodChannel(engine, this)
                Log.d("SayItAccessibility", "Bound MethodChannel to Overlay Engine")
            }
        } catch (e: Exception) {
            Log.e("SayItAccessibility", "Failed to bind to overlay engine: " + e.message)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We can passively listen here, but typically we want to extract text 
        // ON DEMAND when the user clicks the bubble.
    }

    override fun onInterrupt() {
        Log.d("SayItAccessibility", "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d("SayItAccessibility", "Accessibility Service Destroyed")
    }

    // --- On-Demand Methods called via MethodChannel from Flutter ---

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

    // --- Helper Methods ---

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
            // Keep a copy because we might recycle the parent later
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
