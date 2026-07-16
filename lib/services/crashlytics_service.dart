import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService _instance = CrashlyticsService._();
  static CrashlyticsService get instance => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[Crashlytics] Firebase não inicializado.');
        return;
      }
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _initialized = true;
    } catch (e) {
      debugPrint('[Crashlytics] Erro ao inicializar: $e');
    }
  }

  void log(String message) {
    if (!_initialized) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  void recordError(dynamic error, StackTrace? stack, {String? reason}) {
    if (!_initialized) {
      debugPrint('[Crashlytics] (não inicializado) Erro: $error');
      return;
    }
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    } catch (_) {}
  }

  Future<void> setUserId(String id) async {
    if (!_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(id);
    } catch (_) {}
  }
}
