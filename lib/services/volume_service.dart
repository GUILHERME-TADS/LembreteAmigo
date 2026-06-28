import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VolumeService {
  static const _channel = MethodChannel('com.example.lembretes_app/volume');

  static Future<int> getVolumePercentage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMocked = prefs.getBool('mock_low_volume') ?? false;
      if (isMocked) {
        return 10; // Retorna volume baixo para simular alerta (10%)
      }

      final int? volume = await _channel.invokeMethod<int>('getVolume');
      return volume ?? 100;
    } catch (_) {
      // Fallback em caso de erro no MethodChannel (Windows/Web/Simuladores)
      return 100;
    }
  }
}
