import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureCacheService {
  SecureCacheService._();
  static final SecureCacheService instance = SecureCacheService._();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('Falha ao ler cache seguro: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('Falha ao gravar cache seguro: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('Falha ao excluir cache seguro: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }
}
