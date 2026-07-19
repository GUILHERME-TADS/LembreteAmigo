import 'dart:async';
import 'dart:convert';
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
  static const String _callPayloadPrefix = 'incoming_call:';
  static const String callAcceptAction = 'call_accept';
  static const String callDeclineAction = 'call_decline';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  Future<void> requestAlarmPermissions() async {
    if (kIsWeb || !_initialized) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  /// Callback disparado quando o usuário toca em uma notificação de lembrete.
  /// O payload contém o ID do lembrete.
  FutureOr<void> Function(String lembreteId)? onNotificationTapped;

  FutureOr<void> Function(
    String callId,
    String roomName,
    String callType,
    String? actionId,
  )?
  onIncomingCallAction;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (kIsWeb) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
        'Timezone local $timeZoneName nao encontrado: $e. Usando America/Sao_Paulo.',
      );
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    // 2. Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _initialized = true;
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final call = decodeIncomingCallPayload(payload);
    if (call != null) {
      await cancelarChamada(call['callId']!);
      final actionId = response.actionId;
      await onIncomingCallAction?.call(
        call['callId']!,
        call['roomName']!,
        call['callType']!,
        actionId == null || actionId.isEmpty ? null : actionId,
      );
      return;
    }

    await onNotificationTapped?.call(payload);
    _navigatorKey?.currentState?.pushNamed(
      '/active-reminder',
      arguments: payload,
    );
  }

  static String incomingCallPayload({
    required String callId,
    required String roomName,
    required String callType,
  }) {
    return '$_callPayloadPrefix${jsonEncode({'callId': callId, 'roomName': roomName, 'callType': callType})}';
  }

  static Map<String, String>? decodeIncomingCallPayload(String payload) {
    if (!payload.startsWith(_callPayloadPrefix)) return null;
    try {
      final value = jsonDecode(payload.substring(_callPayloadPrefix.length));
      if (value is! Map) return null;
      final callId = value['callId']?.toString() ?? '';
      final roomName = value['roomName']?.toString() ?? '';
      final callType = value['callType']?.toString() ?? 'video';
      if (callId.isEmpty || roomName.isEmpty) return null;
      return {'callId': callId, 'roomName': roomName, 'callType': callType};
    } catch (_) {
      return null;
    }
  }

  Future<void> mostrarChamadaRecebida({
    required String callId,
    required String roomName,
    required String callType,
  }) async {
    if (kIsWeb || !_initialized) return;
    await showIncomingCallNotification(
      plugin: _plugin,
      callId: callId,
      roomName: roomName,
      callType: callType,
    );
  }

  static Future<void> showIncomingCallNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required String callId,
    required String roomName,
    required String callType,
  }) async {
    final isVoice = callType == 'voice';
    final androidDetails = AndroidNotificationDetails(
      'incoming_calls_channel_v1',
      'Chamadas recebidas',
      channelDescription: 'Chamadas de voz e video recebidas',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          callDeclineAction,
          'Recusar',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          callAcceptAction,
          'Atender',
          showsUserInterface: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await plugin.show(
      _stableCallId(callId),
      isVoice ? 'Chamada de voz recebida' : 'Chamada de video recebida',
      'Toque para atender ou recusar',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: incomingCallPayload(
        callId: callId,
        roomName: roomName,
        callType: callType,
      ),
    );
  }

  Future<void> cancelarChamada(String callId) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(_stableCallId(callId));
  }

  static int _stableCallId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in 'call_$value'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
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

  Future<void> cancelarTodas() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
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
    final occurrences = _nextOccurrences(lembrete, now);
    for (var i = 0; i < occurrences.length; i++) {
      await _scheduleReminder(lembrete, occurrences[i], slot: i + 1);
    }
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

  List<tz.TZDateTime> _nextOccurrences(Lembrete lembrete, tz.TZDateTime now) {
    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      final scheduledDate = _nextOneTimeOccurrence(lembrete, now);
      return scheduledDate == null ? const [] : [scheduledDate];
    }

    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      return _monthlyOccurrences(lembrete, now);
    }

    final occurrences = <tz.TZDateTime>[];
    var day = _firstCandidateDay(lembrete, now);
    var checkedDays = 0;
    const maxDaysToCheck = 730;

    while (occurrences.length < _maxGeneratedSlots &&
        checkedDays < maxDaysToCheck &&
        _isOnOrBeforeReminderEnd(lembrete, day)) {
      if (_isReminderActiveOnDay(lembrete, day)) {
        if (lembrete.recorrencia == 'intervalo' ||
            lembrete.recorrenciaIntervalo) {
          occurrences.addAll(_intervalOccurrencesOnDay(lembrete, now, day));
        } else {
          final scheduledDate = _scheduledTimeOnDay(lembrete, day);
          if (scheduledDate.isAfter(now)) {
            occurrences.add(scheduledDate);
          }
        }
      }
      day = day.add(const Duration(days: 1));
      checkedDays++;
    }

    if (occurrences.length > _maxGeneratedSlots) {
      return occurrences.take(_maxGeneratedSlots).toList();
    }
    return occurrences;
  }

  tz.TZDateTime _firstCandidateDay(Lembrete lembrete, tz.TZDateTime now) {
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final start = lembrete.dataInicio;
    if (start == null) return today;

    final startDay = tz.TZDateTime(
      tz.local,
      start.year,
      start.month,
      start.day,
    );
    return startDay.isAfter(today) ? startDay : today;
  }

  tz.TZDateTime _scheduledTimeOnDay(Lembrete lembrete, tz.TZDateTime day) {
    return tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );
  }

  bool _isReminderActiveOnDay(Lembrete lembrete, tz.TZDateTime day) {
    return Lembrete.isReminderActiveOn(
      lembrete,
      DateTime(day.year, day.month, day.day),
    );
  }

  bool _isOnOrBeforeReminderEnd(Lembrete lembrete, tz.TZDateTime day) {
    if (lembrete.isUsoContinuo || lembrete.dataFim == null) return true;
    final end = lembrete.dataFim!;
    final endDay = tz.TZDateTime(tz.local, end.year, end.month, end.day);
    return !day.isAfter(endDay);
  }

  List<tz.TZDateTime> _monthlyOccurrences(
    Lembrete lembrete,
    tz.TZDateTime now,
  ) {
    final occurrences = <tz.TZDateTime>[];
    final day = lembrete.diaMes ?? lembrete.criadoEm.day;
    final firstDay = _firstCandidateDay(lembrete, now);
    var year = firstDay.year;
    var month = firstDay.month;

    for (var i = 0; i < 60 && occurrences.length < _maxGeneratedSlots; i++) {
      final scheduledDate = _monthlyDate(
        year,
        month,
        day,
        lembrete.horarioHour,
        lembrete.horarioMinute,
      );
      if (scheduledDate != null &&
          scheduledDate.isAfter(now) &&
          _isReminderActiveOnDay(lembrete, scheduledDate) &&
          _isOnOrBeforeReminderEnd(lembrete, scheduledDate)) {
        occurrences.add(scheduledDate);
      }

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    return occurrences;
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

  tz.TZDateTime? _nextOneTimeOccurrence(Lembrete lembrete, tz.TZDateTime now) {
    final targetDate = lembrete.dataInicio ?? lembrete.criadoEm;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );
    if (!scheduledDate.isAfter(now)) return null;
    if (!_isReminderActiveOnDay(lembrete, scheduledDate)) return null;
    return scheduledDate;
  }

  List<tz.TZDateTime> _intervalOccurrencesOnDay(
    Lembrete lembrete,
    tz.TZDateTime now,
    tz.TZDateTime day,
  ) {
    final intervalHours = lembrete.intervaloHoras ?? 4;
    final interval = intervalHours <= 0 ? 4 : intervalHours;
    final occurrences = <tz.TZDateTime>[];
    var scheduledDate = _scheduledTimeOnDay(lembrete, day);

    while (scheduledDate.year == day.year &&
        scheduledDate.month == day.month &&
        scheduledDate.day == day.day &&
        occurrences.length < 24) {
      if (scheduledDate.isAfter(now)) {
        occurrences.add(scheduledDate);
      }
      scheduledDate = scheduledDate.add(Duration(hours: interval));
    }
    return occurrences;
  }
}
