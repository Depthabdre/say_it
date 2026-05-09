import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AccessibilityServiceBridge {
  static const MethodChannel _channel = MethodChannel('com.example.say_it/accessibility');

  /// Checks if the TapReply Accessibility Service is currently enabled by the user.
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isAccessibilityEnabled');
      return isEnabled;
    } on PlatformException catch (e) {
      debugPrint("Failed to check accessibility status: '${e.message}'.");
      return false;
    }
  }

  /// Opens the Android system settings page for Accessibility, allowing the user to enable it.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open settings: '${e.message}'.");
    }
  }

  /// Extracts all readable text from the currently active window on the screen.
  static Future<String?> extractScreenText() async {
    try {
      final String? text = await _channel.invokeMethod('extractScreenText');
      return text;
    } on PlatformException catch (e) {
      debugPrint("Failed to extract screen text: '${e.message}'.");
      return null;
    }
  }

  /// Injects the given [text] into the currently focused or active input field.
  static Future<bool> injectText(String text) async {
    try {
      final bool success = await _channel.invokeMethod('injectText', {'text': text});
      return success;
    } on PlatformException catch (e) {
      debugPrint("Failed to inject text: '${e.message}'.");
      return false;
    }
  }
}
