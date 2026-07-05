import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureCacheService {
  SecureCacheService._();
  static final SecureCacheService instance = SecureCacheService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.lembretes_app/secure_cache',
  );

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return null;
    }

    try {
      final value = await _channel.invokeMethod<String>('read', {'key': key});
      if (value != null) return value;
    } on MissingPluginException {
      debugPrint('Secure cache nativo indisponivel para leitura.');
    } on PlatformException catch (e) {
      debugPrint('Falha ao ler cache seguro: ${e.message}');
    } catch (e) {
      debugPrint('Falha inesperada ao ler cache seguro: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    try {
      await _channel.invokeMethod<void>('write', {
        'key': key,
        'value': value,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    } on MissingPluginException {
      debugPrint('Secure cache nativo indisponivel para gravacao.');
    } on PlatformException catch (e) {
      debugPrint('Falha ao gravar cache seguro: ${e.message}');
    } catch (e) {
      debugPrint('Falha inesperada ao gravar cache seguro: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
    } on MissingPluginException {
      debugPrint('Secure cache nativo indisponivel para exclusao.');
    } on PlatformException catch (e) {
      debugPrint('Falha ao excluir cache seguro: ${e.message}');
    } catch (e) {
      debugPrint('Falha inesperada ao excluir cache seguro: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
