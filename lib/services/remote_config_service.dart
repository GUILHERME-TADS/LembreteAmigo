import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig!.setDefaults(const {
        'enable_ai_summary': true,
        'enable_video_calls': true,
        'enable_sos': true,
        'debounce_search_ms': 400,
        'max_reminders_per_page': 200,
        'rate_limit_lembretes_per_min': 30,
        'enable_crashlytics': true,
      });
      await _remoteConfig!.fetchAndActivate();
      _initialized = true;
      debugPrint('RemoteConfig initialized');
    } catch (e) {
      debugPrint('RemoteConfig unavailable: $e');
    }
  }

  bool get isAvailable => _initialized;

  bool getBool(String key) {
    if (!_initialized) return _defaultBool(key);
    try {
      return _remoteConfig!.getBool(key);
    } catch (e) {
      return _defaultBool(key);
    }
  }

  int getInt(String key) {
    if (!_initialized) return _defaultInt(key);
    try {
      return _remoteConfig!.getInt(key);
    } catch (e) {
      return _defaultInt(key);
    }
  }

  double getDouble(String key) {
    if (!_initialized) return _defaultDouble(key);
    try {
      return _remoteConfig!.getDouble(key);
    } catch (e) {
      return _defaultDouble(key);
    }
  }

  String getString(String key) {
    if (!_initialized) return '';
    try {
      return _remoteConfig!.getString(key);
    } catch (e) {
      return '';
    }
  }

  bool _defaultBool(String key) {
    switch (key) {
      case 'enable_ai_summary':
      case 'enable_video_calls':
      case 'enable_sos':
      case 'enable_crashlytics':
        return true;
      default:
        return false;
    }
  }

  int _defaultInt(String key) {
    switch (key) {
      case 'debounce_search_ms':
        return 400;
      case 'max_reminders_per_page':
        return 200;
      case 'rate_limit_lembretes_per_min':
        return 30;
      default:
        return 0;
    }
  }

  double _defaultDouble(String key) {
    return _defaultInt(key).toDouble();
  }
}
