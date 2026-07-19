import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/notification_service.dart';
import '../main.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  StreamSubscription<AlarmSettings>? _ringSubscription;

  void init() {
    _ringSubscription?.cancel();
    // ignore: deprecated_member_use
    _ringSubscription = Alarm.ringStream.stream.listen((AlarmSettings settings) async {
      debugPrint('Alarme tocou! ID: ${settings.id}');
      final lembreteId = NotificationService.instance.getLembreteIdByNotificationId(settings.id);
      if (lembreteId != null) {
        navigatorKey.currentState?.pushNamed('/active-reminder', arguments: lembreteId);
      }
    });
  }

  Future<void> agendarAlarmeLembrete(
      Lembrete lembrete, DateTime date, String audioPath, int id) async {
      
    final isMedication = LembreteCategoria.normalizar(lembrete.categoria) == LembreteCategoria.medicacao;
    final contentTitle = isMedication
        ? '💊 Hora do medicamento'
        : '🔔 Lembrete de ${LembreteCategoria.nome(lembrete.categoria)}';

    final bodyText = (isMedication &&
            lembrete.medicamentoInstrucoes != null &&
            lembrete.medicamentoInstrucoes!.isNotEmpty)
        ? '${lembrete.horarioFormatado} • ${lembrete.titulo}\nInstruções: ${lembrete.medicamentoInstrucoes}\nToque para abrir'
        : '${lembrete.horarioFormatado} • ${lembrete.titulo}\nToque para abrir';

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: date,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0, 
        fadeDuration: const Duration(seconds: 3), 
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: contentTitle,
        body: bodyText,
      ),
      androidFullScreenIntent: false,
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  Future<void> cancelar(int id) async {
    await Alarm.stop(id);
  }
}
