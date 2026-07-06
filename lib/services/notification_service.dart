import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/lembrete.dart';
import '../models/smart_alert.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const int _maxGeneratedSlots = 40;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (kIsWeb) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      debugPrint('Timezone local $timeZoneName nao encontrado. Usando America/Sao_Paulo.');
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

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

    // 6. Request Android permissions needed for alarm-like reminders.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
    _initialized = true;
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    if (kIsWeb || !_initialized) return null;
    return _plugin.getNotificationAppLaunchDetails();
  }

  Future<void> cancelar(String id) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(_notificationIdFor(id));
    for (int slot = 1; slot <= _maxGeneratedSlots; slot++) {
      await _plugin.cancel(_notificationIdFor(id, slot));
    }
  }

  Future<void> mostrarAlertaCuidador(SmartAlert alert) async {
    if (kIsWeb || !_initialized) return;
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
    if (kIsWeb || !_initialized) return;
    final now = tz.TZDateTime.now(tz.local);

    for (final l in lembretes) {
      try {
        await cancelar(l.id);
        if (l.concluido) continue;

        await _agendarLembrete(l, now);
      } catch (e) {
        debugPrint('Erro ao agendar lembrete ${l.id}: $e');
      }
    }
  }

  int _notificationIdFor(String id, [int slot = 0]) {
    return _stableStringHash('${id}_$slot');
  }

  int _stableStringHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _agendarLembrete(Lembrete lembrete, tz.TZDateTime now) async {
    if (lembrete.recorrencia == 'semanal' || lembrete.recorrenciaSemanal) {
      final diasSemana = lembrete.diasSemana.isEmpty
          ? <int>[now.weekday]
          : lembrete.diasSemana;
      for (final day in diasSemana) {
        final scheduledDate = _nextWeekdayOccurrence(lembrete, now, day);
        await _scheduleReminder(
          lembrete,
          scheduledDate,
          slot: day,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      final scheduledDate = _nextMonthlyOccurrence(lembrete, now);
      await _scheduleReminder(
        lembrete,
        scheduledDate,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      return;
    }

    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      final scheduledDate = _nextOneTimeOccurrence(lembrete, now);
      if (scheduledDate == null) return;
      await _scheduleReminder(lembrete, scheduledDate);
      return;
    }

    if (lembrete.recorrencia == 'quinzenal') {
      final scheduledDate = _nextFortnightOccurrence(lembrete, now);
      await _scheduleReminder(lembrete, scheduledDate);
      return;
    }

    if (lembrete.recorrencia == 'intervalo' || lembrete.recorrenciaIntervalo) {
      final interval = lembrete.intervaloHoras ?? 4;
      final scheduledDates = _intervalOccurrences(lembrete, now, interval);
      for (var i = 0; i < scheduledDates.length; i++) {
        await _scheduleReminder(
          lembrete,
          scheduledDates[i],
          slot: i + 1,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      return;
    }

    final scheduledDate = _nextDailyOccurrence(lembrete, now);
    await _scheduleReminder(
      lembrete,
      scheduledDate,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleReminder(
    Lembrete lembrete,
    tz.TZDateTime scheduledDate, {
    int slot = 0,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await _plugin.zonedSchedule(
      _notificationIdFor(lembrete.id, slot),
      'Hora do Lembrete Amigo!',
      lembrete.titulo,
      scheduledDate,
      _reminderNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: lembrete.id,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  NotificationDetails _reminderNotificationDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'lembretes_alarm_channel',
          'Alarmes de Lembretes',
          channelDescription: 'Canal de alarmes para lembretes importantes',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  tz.TZDateTime _baseDateForToday(Lembrete lembrete, tz.TZDateTime now) {
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );
  }

  tz.TZDateTime _nextDailyOccurrence(Lembrete lembrete, tz.TZDateTime now) {
    var scheduledDate = _baseDateForToday(lembrete, now);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextWeekdayOccurrence(
    Lembrete lembrete,
    tz.TZDateTime now,
    int weekday,
  ) {
    var scheduledDate = _baseDateForToday(lembrete, now);
    final daysToAdd = (weekday - now.weekday) % DateTime.daysPerWeek;
    scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextMonthlyOccurrence(Lembrete lembrete, tz.TZDateTime now) {
    final day = lembrete.diaMes ?? lembrete.criadoEm.day;
    var year = now.year;
    var month = now.month;

    for (var i = 0; i < 24; i++) {
      final scheduledDate = _monthlyDate(
        year,
        month,
        day,
        lembrete.horarioHour,
        lembrete.horarioMinute,
      );
      if (scheduledDate != null && scheduledDate.isAfter(now)) {
        return scheduledDate;
      }

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    return _nextDailyOccurrence(lembrete, now);
  }

  tz.TZDateTime? _monthlyDate(
    int year,
    int month,
    int preferredDay,
    int hour,
    int minute,
  ) {
    final lastDay = DateTime(year, month + 1, 0).day;
    var day = preferredDay;
    if (day < 1) day = 1;
    if (day > lastDay) return null;
    return tz.TZDateTime(tz.local, year, month, day, hour, minute);
  }

  tz.TZDateTime? _nextOneTimeOccurrence(
    Lembrete lembrete,
    tz.TZDateTime now,
  ) {
    final created = lembrete.criadoEm;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      created.year,
      created.month,
      created.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );
    return scheduledDate.isAfter(now) ? scheduledDate : null;
  }

  tz.TZDateTime _nextFortnightOccurrence(
    Lembrete lembrete,
    tz.TZDateTime now,
  ) {
    final createdDate = DateTime(
      lembrete.criadoEm.year,
      lembrete.criadoEm.month,
      lembrete.criadoEm.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    var diffDays = today.difference(createdDate).inDays;
    if (diffDays < 0) diffDays = 0;

    final remainder = diffDays % 15;
    final daysToAdd = remainder == 0 ? 0 : 15 - remainder;
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    ).add(Duration(days: daysToAdd));

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 15));
    }
    return scheduledDate;
  }

  List<tz.TZDateTime> _intervalOccurrences(
    Lembrete lembrete,
    tz.TZDateTime now,
    int intervalHours,
  ) {
    final interval = intervalHours <= 0 ? 4 : intervalHours;
    final occurrences = <tz.TZDateTime>[];
    var scheduledDate = _baseDateForToday(lembrete, now);

    while (scheduledDate.day == now.day && occurrences.length < 24) {
      if (!scheduledDate.isBefore(now)) {
        occurrences.add(scheduledDate);
      }
      scheduledDate = scheduledDate.add(Duration(hours: interval));
    }

    if (occurrences.isEmpty) {
      occurrences.add(
        _baseDateForToday(lembrete, now).add(const Duration(days: 1)),
      );
    }
    return occurrences;
  }
}
