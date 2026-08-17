import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/lembrete.dart';
import '../services/notification_service.dart';
import '../services/session_role_service.dart';
import '../services/lembrete_service.dart';
import '../main.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  StreamSubscription<AlarmSettings>? _ringSubscription;
  final List<String> _pendingActiveReminderQueue = [];
  bool _isNavigatingToReminder = false;

  List<String> get pendingQueue => List.unmodifiable(_pendingActiveReminderQueue);

  void init() {
    _ringSubscription?.cancel();
    // ignore: deprecated_member_use
    _ringSubscription = Alarm.ringStream.stream.listen((
      AlarmSettings settings,
    ) async {
      debugPrint('Alarme tocou! ID: ${settings.id}');
      final lembreteId = NotificationService.instance
          .getLembreteIdByNotificationId(settings.id);
      if (lembreteId != null) {
        showOrEnqueueReminder(lembreteId);
      }
    });
  }

  void showOrEnqueueReminder(String lembreteId) {
    if (SessionRoleService.isSupervisor) return;

    final isReminderRouteActive = RouteTracker.instance.isReminderRouteActive;

    if (isReminderRouteActive || _isNavigatingToReminder) {
      if (!_pendingActiveReminderQueue.contains(lembreteId)) {
        _pendingActiveReminderQueue.add(lembreteId);
        debugPrint('Lembrete $lembreteId adicionado à fila de espera de alarmes.');
      }
      return;
    }

    _isNavigatingToReminder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _isNavigatingToReminder = false;
        return;
      }
      nav
          .pushNamed('/active-reminder', arguments: lembreteId)
          .then((_) {
            _isNavigatingToReminder = false;
            processNextPendingReminder();
          })
          .catchError((error) {
            debugPrint('Erro ao navegar para o lembrete ativo: $error');
            _isNavigatingToReminder = false;
          });
    });
  }

  void processNextPendingReminder() {
    if (_pendingActiveReminderQueue.isEmpty || _isNavigatingToReminder) return;
    if (RouteTracker.instance.isReminderRouteActive) return;

    final nextId = _pendingActiveReminderQueue.removeAt(0);

    // Checa se o lembrete já foi concluído enquanto esperava
    final lembretes = LembreteService.instance.lembretes;
    final match = lembretes.where((l) => l.id == nextId);
    if (match.isNotEmpty && match.first.concluido) {
      processNextPendingReminder();
      return;
    }

    showOrEnqueueReminder(nextId);
  }

  void clearQueue() {
    _pendingActiveReminderQueue.clear();
    _isNavigatingToReminder = false;
  }

  Future<bool> canScheduleReminders() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final notificationsGranted = await Permission.notification.isGranted;
    final exactAlarmsGranted = await Permission.scheduleExactAlarm.isGranted;
    return notificationsGranted && exactAlarmsGranted;
  }

  Future<Set<int>> scheduledAlarmIds() async {
    try {
      final alarms = await Alarm.getAlarms();
      return alarms.map((alarm) => alarm.id).toSet();
    } catch (error) {
      debugPrint('Nao foi possivel consultar os alarmes ativos: $error');
      return const <int>{};
    }
  }

  Future<bool> agendarAlarmeLembrete(
    Lembrete lembrete,
    DateTime date,
    String audioPath,
    int id,
  ) async {
    if (!await canScheduleReminders()) {
      debugPrint(
        'Alarme $id nao agendado: notificacoes ou alarmes exatos bloqueados.',
      );
      return false;
    }

    final alarmSettings = buildReminderAlarmSettings(
      lembrete: lembrete,
      date: date,
      audioPath: audioPath,
      id: id,
    );
    return Alarm.set(alarmSettings: alarmSettings);
  }

  @visibleForTesting
  AlarmSettings buildReminderAlarmSettings({
    required Lembrete lembrete,
    required DateTime date,
    required String audioPath,
    required int id,
  }) {
    final isMedication =
        LembreteCategoria.normalizar(lembrete.categoria) ==
        LembreteCategoria.medicacao;
    final contentTitle = isMedication
        ? '💊 Hora do medicamento'
        : '🔔 Lembrete de ${LembreteCategoria.nome(lembrete.categoria)}';

    final bodyText =
        (isMedication &&
            lembrete.medicamentoInstrucoes != null &&
            lembrete.medicamentoInstrucoes!.isNotEmpty)
        ? '${lembrete.horarioFormatado} • ${lembrete.titulo}\nInstruções: ${lembrete.medicamentoInstrucoes}\nToque para abrir'
        : '${lembrete.horarioFormatado} • ${lembrete.titulo}\nToque para abrir';

    return AlarmSettings(
      id: id,
      dateTime: date,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      allowSameSecondScheduling: true,
      allowAlarmOverlap: false,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        fadeDuration: const Duration(seconds: 3),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: contentTitle,
        body: bodyText,
      ),
      warningNotificationOnKill: defaultTargetPlatform == TargetPlatform.iOS,
      androidFullScreenIntent: false,
    );
  }

  Future<void> cancelar(int id) async {
    await Alarm.stop(id);
  }
}
