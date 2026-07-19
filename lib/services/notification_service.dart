import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lembrete.dart';
import '../models/smart_alert.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/alarm_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const int _maxGeneratedSlots = 40;
  static const String _callPayloadPrefix = 'incoming_call:';
  static const String _messagePayloadPrefix = 'app_message:';
  static const String _missedCallPayloadPrefix = 'missed_call:';
  static const String _supervisorAlertPayloadPrefix = 'supervisor_alert:';
  static const String callAcceptAction = 'call_accept';
  static const String callDeclineAction = 'call_decline';
  static const String messageOpenAction = 'message_open';
  static const String messageReadAction = 'message_read';
  static const String supervisorOpenAction = 'supervisor_open';
  static const String supervisorCallAction = 'supervisor_call';
  static const String _messageCategory = 'message_actions';
  static const String _callCategory = 'incoming_call_actions';
  static const String _scheduledRegistryKey = 'scheduled_reminder_registry_v2';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  final Set<String> _processingActions = <String>{};
  final Map<String, Timer> _callExpiryTimers = <String, Timer>{};
  final Map<String, Set<int>> _scheduledReminderIds = <String, Set<int>>{};
  final Map<String, String> _scheduledReminderSignatures = <String, String>{};
  Future<void>? _registryLoadFuture;
  Future<void> _scheduleTail = Future<void>.value();
  final Set<int> _pendingNotificationCancellations = <int>{};
  Timer? _cancellationTimer;
  bool _cancellingNotification = false;

  void _queueCancellations(Iterable<int> ids) {
    _pendingNotificationCancellations.addAll(ids);
    if (_pendingNotificationCancellations.isEmpty ||
        (_cancellationTimer?.isActive ?? false)) {
      return;
    }
    _cancellationTimer = Timer.periodic(
      const Duration(milliseconds: 220),
      (timer) async {
        if (_cancellingNotification) return;
        if (_pendingNotificationCancellations.isEmpty) {
          timer.cancel();
          _cancellationTimer = null;
          return;
        }
        _cancellingNotification = true;
        final notificationId = _pendingNotificationCancellations.first;
        _pendingNotificationCancellations.remove(notificationId);
        try {
          await _plugin.cancel(notificationId);
          await AlarmService.instance.cancelar(notificationId);
        } finally {
          _cancellingNotification = false;
        }
      },
    );
  }

  Future<void> _loadScheduledRegistry() {
    return _registryLoadFuture ??= () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scheduledRegistryKey);
      if (raw == null || raw.isEmpty) return;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);
          _scheduledReminderIds[entry.key] = (value['ids'] as List? ?? const [])
              .map((item) => (item as num).toInt())
              .toSet();
          _scheduledReminderSignatures[entry.key] =
              value['signature'] as String? ?? '';
        }
      } catch (_) {
        await prefs.remove(_scheduledRegistryKey);
      }
    }();
  }

  Future<void> _saveScheduledRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final entry in _scheduledReminderIds.entries) {
      data[entry.key] = {
        'ids': entry.value.toList(),
        'signature': _scheduledReminderSignatures[entry.key] ?? '',
      };
    }
    await prefs.setString(_scheduledRegistryKey, jsonEncode(data));
  }

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
  FutureOr<void> Function(String messageId, String actionId)? onMessageAction;

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
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _callCategory,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(callAcceptAction, 'Atender',
                    options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground}),
                DarwinNotificationAction.plain(callDeclineAction, 'Recusar',
                    options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground}),
              ],
            ),
            DarwinNotificationCategory(
              _messageCategory,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(messageOpenAction, 'Abrir recado',
                    options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground}),
                DarwinNotificationAction.plain(messageReadAction, 'Marcar como lido',
                    options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground}),
              ],
            ),
          ],
        );

    // 4. Combined settings
    final InitializationSettings initializationSettings =
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
      await _runOnce(
        '${actionId ?? 'open'}:${call['callId']}',
        () => onIncomingCallAction?.call(
          call['callId']!,
          call['roomName']!,
          call['callType']!,
          actionId == null || actionId.isEmpty ? null : actionId,
        ),
      );
      return;
    }

    if (payload.startsWith(_messagePayloadPrefix)) {
      final messageId = payload.substring(_messagePayloadPrefix.length);
      if (response.actionId == messageReadAction ||
          response.actionId == messageOpenAction) {
        await _runOnce(
          '${response.actionId}:$messageId',
          () => onMessageAction?.call(messageId, response.actionId!),
        );
        if (response.actionId == messageReadAction) {
          await _plugin.cancel(_stableStringHash('message_$messageId'));
          return;
        }
      }
      _navigatorKey?.currentState?.pushNamed('/messages');
      return;
    }

    if (payload.startsWith(_missedCallPayloadPrefix)) {
      _navigatorKey?.currentState?.pushNamed('/video-call-history');
      return;
    }

    if (payload.startsWith(_supervisorAlertPayloadPrefix)) {
      _navigatorKey?.currentState?.pushNamed(
        response.actionId == supervisorCallAction
            ? '/video-call-history'
            : '/supervisor-dashboard',
      );
      return;
    }

    if (isMissedCallPayload(payload)) {
      _navigatorKey?.currentState?.pushNamed('/video-call-history');
      return;
    }

    await onNotificationTapped?.call(payload);
    _navigatorKey?.currentState?.pushNamed(
      '/active-reminder',
      arguments: payload,
    );
  }

  Future<void> _runOnce(
    String key,
    FutureOr<void> Function() operation,
  ) async {
    if (!_processingActions.add(key)) return;
    try {
      await operation();
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        _processingActions.remove(key);
      });
    }
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

  static String appMessagePayload(String messageId) {
    return '$_messagePayloadPrefix$messageId';
  }

  static bool isAppMessagePayload(String payload) {
    return payload.startsWith(_messagePayloadPrefix);
  }

  static bool isMissedCallPayload(String payload) {
    return payload.startsWith(_missedCallPayloadPrefix);
  }

  static bool isSupervisorAlertPayload(String payload) {
    return payload.startsWith(_supervisorAlertPayloadPrefix);
  }

  Future<void> mostrarChamadaRecebida({
    required String callId,
    required String roomName,
    required String callType,
    String? callerName,
  }) async {
    if (kIsWeb || !_initialized) return;
    await cancelarChamada(callId);
    await showIncomingCallNotification(
      plugin: _plugin,
      callId: callId,
      roomName: roomName,
      callType: callType,
      callerName: callerName,
    );
    _callExpiryTimers[callId] = Timer(const Duration(seconds: 45), () {
      _callExpiryTimers.remove(callId);
      mostrarChamadaPerdida(
        callId: callId,
        callType: callType,
        callerName: callerName,
      );
    });
  }

  Future<void> mostrarNovoRecado({
    required String messageId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;
    final androidDetails = AndroidNotificationDetails(
      'app_messages_channel_v1',
      'Recados recebidos',
      channelDescription: 'Avisos de novos recados entre idoso e cuidador',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      playSound: true,
      enableVibration: true,
      color: AppColors.primary,
      ledColor: AppColors.primary,
      ledOnMs: 1000,
      ledOffMs: 1000,
      groupKey: 'lembrete_amigo_recados',
      visibility: NotificationVisibility.private,
      number: 1,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Recado',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          messageOpenAction,
          'Abrir recado',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          messageReadAction,
          'Marcar como lido',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      categoryIdentifier: _messageCategory,
      threadIdentifier: 'lembrete_amigo_recados',
      badgeNumber: 1,
    );
    await _plugin.show(
      _stableStringHash('message_$messageId'),
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: appMessagePayload(messageId),
    );
  }

  static Future<void> showIncomingCallNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required String callId,
    required String roomName,
    required String callType,
    String? callerName,
  }) async {
    final isVoice = callType == 'voice';
    final androidDetails = AndroidNotificationDetails(
      isVoice ? 'voice_calls_channel_v2' : 'video_calls_channel_v2',
      isVoice ? 'Chamadas de voz' : 'Chamadas de vídeo',
      channelDescription: isVoice
          ? 'Toques de chamadas de voz recebidas'
          : 'Toques de chamadas de vídeo recebidas',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 1000, 1000, 1000, 1000, 1000, 1000]),
      color: AppColors.primary,
      ledColor: AppColors.secondaryFixedDim,
      ledOnMs: 1000,
      ledOffMs: 500,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      timeoutAfter: 45000,
      groupKey: 'lembrete_amigo_chamadas',
      onlyAlertOnce: true,
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
      categoryIdentifier: _callCategory,
      threadIdentifier: 'lembrete_amigo_chamadas',
    );
    await plugin.show(
      _stableCallId(callId),
      isVoice ? 'Chamada de voz recebida' : 'Chamada de vídeo recebida',
      callerName == null || callerName.trim().isEmpty
          ? 'Toque para atender ou recusar'
          : '${callerName.trim()} está ligando',
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
    _callExpiryTimers.remove(callId)?.cancel();
    await _plugin.cancel(_stableCallId(callId));
  }

  Future<void> mostrarChamadaPerdida({
    required String callId,
    required String callType,
    String? callerName,
  }) async {
    if (kIsWeb || !_initialized) return;
    await cancelarChamada(callId);
    final isVoice = callType == 'voice';
    final title = isVoice ? 'Chamada de voz perdida' : 'Chamada de vídeo perdida';
    final body = callerName == null || callerName.trim().isEmpty
        ? 'Você não atendeu esta chamada'
        : 'Chamada não atendida de ${callerName.trim()}';

    final androidDetails = AndroidNotificationDetails(
      'missed_calls_channel_v1',
      'Chamadas perdidas',
      channelDescription: 'Avisos de chamadas não atendidas',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.missedCall,
      color: AppColors.error,
      groupKey: 'lembrete_amigo_chamadas',
      visibility: NotificationVisibility.private,
      number: 1,
      onlyAlertOnce: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Chamada Perdida',
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'lembrete_amigo_chamadas',
    );
    await _plugin.show(
      _stableStringHash('missed_$callId'),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: '$_missedCallPayloadPrefix$callId',
    );
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
    await _loadScheduledRegistry();
    final ids = _scheduledReminderIds.remove(id) ?? const <int>{};
    _scheduledReminderSignatures.remove(id);
    _queueCancellations(ids);
    if (ids.isNotEmpty) await _saveScheduledRegistry();
  }

  Future<void> cancelarTodas() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
    _cancellationTimer?.cancel();
    _cancellationTimer = null;
    _pendingNotificationCancellations.clear();
    _scheduledReminderIds.clear();
    _scheduledReminderSignatures.clear();
    await _saveScheduledRegistry();
  }

  Future<void> mostrarAlertaCuidador(SmartAlert alert) async {
    if (kIsWeb || !_initialized) return;
    final isUrgent = alert.severity != SmartAlertSeverity.info;
    final alertColor = isUrgent ? AppColors.error : AppColors.primary;
    final androidDetails = AndroidNotificationDetails(
      'cuidador_alertas_channel',
      'Alertas do Cuidador',
      channelDescription:
          'Alertas inteligentes sobre atrasos e dificuldades nos lembretes',
      importance: isUrgent ? Importance.max : Importance.defaultImportance,
      priority: isUrgent ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      color: alertColor,
      ledColor: alertColor,
      ledOnMs: 1000,
      ledOffMs: 1000,
      category: AndroidNotificationCategory.reminder,
      groupKey: 'lembrete_amigo_cuidador',
      onlyAlertOnce: true,
      visibility: NotificationVisibility.private,
      styleInformation: BigTextStyleInformation(
        alert.message,
        contentTitle: alert.title,
        summaryText: 'Alerta Cuidador',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          supervisorOpenAction,
          'Ver alerta',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          supervisorCallAction,
          'Ligar',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    await _plugin.show(
      _stableStringHash('alert_${alert.key}'),
      alert.title,
      alert.message,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: '$_supervisorAlertPayloadPrefix${alert.lembreteId}',
    );
  }

  Future<void> mostrarConfirmacaoCuidador({
    required Lembrete lembrete,
    required LembreteStatus status,
  }) async {
    if (kIsWeb || !_initialized) return;
    final urgent = status == LembreteStatus.precisaDeAjuda ||
        status == LembreteStatus.perdido;
    final action = switch (status) {
      LembreteStatus.concluido ||
      LembreteStatus.concluidoComFoto ||
      LembreteStatus.confirmadoPeloCuidador => 'concluiu',
      LembreteStatus.adiado => 'adiou',
      LembreteStatus.precisaDeAjuda => 'pediu ajuda em',
      LembreteStatus.perdido => 'não realizou',
      _ => 'atualizou',
    };
    final title = urgent ? 'Atenção necessária' : 'Lembrete atualizado';
    final body = 'O idoso $action “${lembrete.titulo}”.';
    final alertColor = urgent ? AppColors.error : AppColors.primary;

    final androidDetails = AndroidNotificationDetails(
      urgent ? 'cuidador_urgente_channel_v2' : 'cuidador_status_channel_v2',
      urgent ? 'Alertas urgentes do idoso' : 'Confirmações do idoso',
      channelDescription: 'Atualizações dos lembretes acompanhados',
      importance: urgent ? Importance.max : Importance.defaultImportance,
      priority: urgent ? Priority.max : Priority.defaultPriority,
      playSound: urgent,
      enableVibration: urgent,
      color: alertColor,
      ledColor: alertColor,
      ledOnMs: 1000,
      ledOffMs: 1000,
      category: AndroidNotificationCategory.status,
      groupKey: 'lembrete_amigo_cuidador',
      onlyAlertOnce: true,
      visibility: NotificationVisibility.private,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Status Lembrete',
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      threadIdentifier: 'lembrete_amigo_cuidador',
    );
    await _plugin.show(
      _stableStringHash('status_${lembrete.id}_${status.storageValue}'),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: '$_supervisorAlertPayloadPrefix${lembrete.id}',
    );
  }

  Future<void> agendarTodos(List<Lembrete> lembretes) async {
    if (kIsWeb || !_initialized) return;
    final snapshot = List<Lembrete>.from(lembretes);
    final operation = _scheduleTail.then((_) => _agendarTodosInterno(snapshot));
    _scheduleTail = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Erro ao atualizar agenda de notificações: $error');
    });
    await operation;
  }

  Future<void> _agendarTodosInterno(List<Lembrete> lembretes) async {
    await _loadScheduledRegistry();
    final now = tz.TZDateTime.now(tz.local);
    final activeIds = lembretes.map((item) => item.id).toSet();

    for (final removedId
        in _scheduledReminderIds.keys.where((id) => !activeIds.contains(id)).toList()) {
      final ids = _scheduledReminderIds.remove(removedId) ?? const <int>{};
      _scheduledReminderSignatures.remove(removedId);
      _queueCancellations(ids);
    }

    for (final l in lembretes) {
      try {
        final signature = jsonEncode(l.toJson());
        if (_scheduledReminderSignatures[l.id] == signature) continue;
        final oldIds = _scheduledReminderIds[l.id] ?? const <int>{};
        if (l.concluido) {
          _queueCancellations(oldIds);
          _scheduledReminderIds.remove(l.id);
          _scheduledReminderSignatures.remove(l.id);
          continue;
        }
        _scheduledReminderIds[l.id] = <int>{};
        await _agendarLembrete(l, now);
        final newIds = _scheduledReminderIds[l.id] ?? const <int>{};
        _queueCancellations(oldIds.difference(newIds));
        _scheduledReminderSignatures[l.id] = signature;
      } catch (e) {
        debugPrint('Erro ao agendar lembrete ${l.id}: $e');
      }
    }
    await _saveScheduledRegistry();
  }

  int _notificationIdFor(String id, [int slot = 0]) {
    return _stableStringHash('${id}_$slot');
  }

  String? getLembreteIdByNotificationId(int notificationId) {
    for (final entry in _scheduledReminderIds.entries) {
      if (entry.value.contains(notificationId)) return entry.key;
    }
    return null;
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
    final notificationId = _notificationIdFor(lembrete.id, slot);
    _pendingNotificationCancellations.remove(notificationId);
    
    // Usa o AlarmService (Pacote alarm) com o áudio do despertador fixo
    final audioPath = 'assets/alarm.mp3';
    
    await AlarmService.instance.agendarAlarmeLembrete(lembrete, scheduledDate, audioPath, notificationId);
    
    _scheduledReminderIds.putIfAbsent(lembrete.id, () => <int>{}).add(
          notificationId,
        );
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
