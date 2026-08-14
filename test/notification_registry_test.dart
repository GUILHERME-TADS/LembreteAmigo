import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'carrega o vínculo do alarme antes da inicialização das notificações',
    () async {
      SharedPreferences.setMockInitialValues({
        'scheduled_reminder_registry_v2': jsonEncode({
          'reminder-cold-start': {
            'ids': [74123],
            'signature': 'test',
          },
        }),
      });

      await NotificationService.instance.prepareReminderRegistry();

      expect(
        NotificationService.instance.getLembreteIdByNotificationId(74123),
        'reminder-cold-start',
      );
    },
  );
}
