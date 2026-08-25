import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureCacheService {
  SecureCacheService._();
  static final SecureCacheService instance = SecureCacheService._();

  /// Serializa qualquer objeto ou mapa para JSON de forma segura,
  /// convertendo automaticamente instâncias do Firestore como [Timestamp] para strings ISO-8601.
  static String safeJsonEncode(dynamic data) {
    return jsonEncode(data, toEncodable: _toEncodable);
  }

  static dynamic _toEncodable(dynamic nonEncodable) {
    if (nonEncodable is Timestamp) {
      return nonEncodable.toDate().toIso8601String();
    }
    if (nonEncodable is DateTime) {
      return nonEncodable.toIso8601String();
    }
    return nonEncodable.toString();
  }

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Map<String, String> _webSessionCache = <String, String>{};
  static const String _elderlyProfileKey = 'idoso_perfil';

  Future<String?> readElderlyProfile() async {
    final protectedValue = await read(_elderlyProfileKey);
    if (protectedValue != null) return protectedValue;

    // One-time migration from versions that stored personal data in plaintext.
    final preferences = await SharedPreferences.getInstance();
    final legacyValue = preferences.getString(_elderlyProfileKey);
    if (legacyValue == null) return null;

    await write(_elderlyProfileKey, legacyValue);
    await preferences.remove(_elderlyProfileKey);
    return legacyValue;
  }

  Future<void> writeElderlyProfile(String value) async {
    await write(_elderlyProfileKey, value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_elderlyProfileKey);
  }

  Future<void> deleteElderlyProfile() async {
    await delete(_elderlyProfileKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_elderlyProfileKey);
  }

  Future<String?> read(String key) async {
    if (kIsWeb) {
      return _webSessionCache[key];
    }

    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('Falha ao ler cache seguro: $e');
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      _webSessionCache[key] = value;
      return;
    }

    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('Falha ao gravar cache seguro: $e');
      rethrow;
    }
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      _webSessionCache.remove(key);
      return;
    }

    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('Falha ao excluir cache seguro: $e');
      rethrow;
    }
  }
}
