import 'package:flutter/services.dart';

class VibrationService {
  static const _channel = MethodChannel('com.example.lembretes_app/vibration');

  static Future<void> startVibration() async {
    try {
      await _channel.invokeMethod('startVibration');
    } catch (_) {
      // Fallback or silently fail on simulator/unsupported platforms
    }
  }

  static Future<void> stopVibration() async {
    try {
      await _channel.invokeMethod('stopVibration');
    } catch (_) {
      // Fallback
    }
  }
}
