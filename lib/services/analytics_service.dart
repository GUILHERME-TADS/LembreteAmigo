import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get analytics {
    if (_analytics == null) {
      try {
        _analytics = FirebaseAnalytics.instance;
      } catch (e) {
        debugPrint('Analytics unavailable: $e');
      }
    }
    return _analytics;
  }

  bool get isAvailable {
    return analytics != null;
  }

  Future<void> logScreenView({required String screenName}) async {
    if (!isAvailable) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    } catch (e) {
      debugPrint('Analytics logScreenView error: $e');
    }
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!isAvailable) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics logEvent error: $e');
    }
  }

  Future<void> logReminderCompleted(String reminderId, String category) async {
    await logEvent(
      name: 'lembrete_concluido',
      parameters: {
        'reminder_id': reminderId,
        'category': category,
      },
    );
  }

  Future<void> logSOSActivated() async {
    await logEvent(name: 'sos_ativado');
  }

  Future<void> logError(String errorMessage, String context) async {
    await logEvent(
      name: 'erro_app',
      parameters: {
        'message': errorMessage,
        'context': context,
      },
    );
  }

  Future<void> logVideoCallInitiated() async {
    await logEvent(name: 'video_chamada_iniciada');
  }

  Future<void> setUserId(String? userId) async {
    if (!isAvailable) return;
    try {
      await _analytics!.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics setUserId error: $e');
    }
  }
}
