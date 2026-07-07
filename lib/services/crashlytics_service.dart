import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService _instance = CrashlyticsService._();
  static CrashlyticsService get instance => _instance;

  Future<void> init() async {
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  void recordError(dynamic error, StackTrace? stack, {String? reason}) {
    FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
  }

  Future<void> setUserId(String id) async {
    await FirebaseCrashlytics.instance.setUserIdentifier(id);
  }
}
