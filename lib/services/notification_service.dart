import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/lembrete.dart';
import '../models/smart_alert.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 2. Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // 4. Combined settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // 5. Initialize plugin with click handler
    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _navigatorKey?.currentState?.pushNamed(
            '/active-reminder',
            arguments: payload,
          );
        }
      },
    );

    // 6. Request permissions for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    return _plugin.getNotificationAppLaunchDetails();
  }

  Future<void> cancelar(String id) async {
    final int notificationId = int.tryParse(id) != null
        ? (int.parse(id) % 2147483647)
        : id.hashCode;
    await _plugin.cancel(notificationId);
    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel((notificationId + day * 100000) % 2147483647);
    }
  }

  Future<void> mostrarAlertaCuidador(SmartAlert alert) async {
    final androidDetails = AndroidNotificationDetails(
      'cuidador_alertas_channel',
      'Alertas do Cuidador',
      channelDescription:
          'Alertas inteligentes sobre atrasos e dificuldades nos lembretes',
      importance: alert.severity == SmartAlertSeverity.info
          ? Importance.defaultImportance
          : Importance.max,
      priority: alert.severity == SmartAlertSeverity.info
          ? Priority.defaultPriority
          : Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      alert.key.hashCode & 0x7fffffff,
      alert.title,
      alert.message,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: alert.lembreteId,
    );
  }

  Future<void> agendarTodos(List<Lembrete> lembretes) async {
    // Cancel all previous scheduled alerts to avoid duplicates
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    for (final l in lembretes) {
      // Don't schedule notifications for completed reminders
      if (l.concluido) continue;

      final int notificationId = int.tryParse(l.id) != null
          ? (int.parse(l.id) % 2147483647)
          : l.hashCode;

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        l.horarioHour,
        l.horarioMinute,
      );

      // If scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'lembretes_channel',
            'Lembretes Diários',
            channelDescription:
                'Canal de notificações para alarmes de lembretes',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        notificationId,
        'Hora do Lembrete Amigo!',
        l.titulo,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: l.id,
        matchDateTimeComponents:
            DateTimeComponents.time, // Repeats daily at this time
      );
    }
  }
}
