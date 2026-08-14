import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'session_role_service.dart';

class CarePreferences {
  final bool simpleHomeEnabled;
  final bool dailySummaryEnabled;
  final int dailySummaryHour;
  final int dailySummaryMinute;

  const CarePreferences({
    this.simpleHomeEnabled = true,
    this.dailySummaryEnabled = true,
    this.dailySummaryHour = 20,
    this.dailySummaryMinute = 0,
  });

  CarePreferences copyWith({
    bool? simpleHomeEnabled,
    bool? dailySummaryEnabled,
    int? dailySummaryHour,
    int? dailySummaryMinute,
  }) {
    return CarePreferences(
      simpleHomeEnabled: simpleHomeEnabled ?? this.simpleHomeEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      dailySummaryHour: dailySummaryHour ?? this.dailySummaryHour,
      dailySummaryMinute: dailySummaryMinute ?? this.dailySummaryMinute,
    );
  }
}

class CarePreferencesService {
  CarePreferencesService._();

  static final CarePreferencesService instance = CarePreferencesService._();

  static const _simpleHomeKey = 'care_simple_home_enabled_v1';
  static const _dailySummaryKey = 'care_daily_summary_enabled_v1';
  static const _dailySummaryHourKey = 'care_daily_summary_hour_v1';
  static const _dailySummaryMinuteKey = 'care_daily_summary_minute_v1';

  final ValueNotifier<CarePreferences> notifier = ValueNotifier(
    const CarePreferences(),
  );

  bool _loaded = false;
  CarePreferences get value => notifier.value;

  Future<CarePreferences> load() async {
    if (_loaded) return value;
    final prefs = await SharedPreferences.getInstance();
    notifier.value = CarePreferences(
      simpleHomeEnabled: prefs.getBool(_simpleHomeKey) ?? true,
      dailySummaryEnabled: prefs.getBool(_dailySummaryKey) ?? true,
      dailySummaryHour: (prefs.getInt(_dailySummaryHourKey) ?? 20).clamp(0, 23),
      dailySummaryMinute: (prefs.getInt(_dailySummaryMinuteKey) ?? 0).clamp(
        0,
        59,
      ),
    );
    _loaded = true;
    return value;
  }

  Future<void> setSimpleHomeEnabled(bool enabled) async {
    await load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simpleHomeKey, enabled);
    notifier.value = value.copyWith(simpleHomeEnabled: enabled);
  }

  Future<void> setDailySummary({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await load();
    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailySummaryKey, enabled);
    await prefs.setInt(_dailySummaryHourKey, safeHour);
    await prefs.setInt(_dailySummaryMinuteKey, safeMinute);
    notifier.value = value.copyWith(
      dailySummaryEnabled: enabled,
      dailySummaryHour: safeHour,
      dailySummaryMinute: safeMinute,
    );
    await restoreDailySummarySchedule();
  }

  Future<void> restoreDailySummarySchedule() async {
    await load();
    if (!SessionRoleService.isSupervisor || !value.dailySummaryEnabled) {
      await NotificationService.instance.cancelDailySummary();
      return;
    }
    await NotificationService.instance.scheduleDailySummary(
      hour: value.dailySummaryHour,
      minute: value.dailySummaryMinute,
    );
  }
}
