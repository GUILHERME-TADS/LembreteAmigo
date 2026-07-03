import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/smart_alert.dart';
import 'notification_service.dart';

class SmartAlertService {
  SmartAlertService._();
  static final SmartAlertService instance = SmartAlertService._();

  final ValueNotifier<List<SmartAlert>> notifier = ValueNotifier([]);

  List<SmartAlert> get alerts => List.unmodifiable(notifier.value);

  Future<void> atualizar(
    List<Lembrete> lembretes, {
    DateTime? now,
    int? bpm,
  }) async {
    final detected = detectarAlertas(
      lembretes,
      now: now ?? DateTime.now(),
      bpm: bpm,
    );
    notifier.value = detected;
    await _notifyNewAlerts(detected);
  }

  List<SmartAlert> detectarAlertas(
    List<Lembrete> lembretes, {
    required DateTime now,
    int? bpm,
  }) {
    final alerts = <SmartAlert>[];

    for (final lembrete in lembretes) {
      if (!_isReminderActiveToday(lembrete, now)) continue;
      if (lembrete.status.isConcluido) continue;

      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        lembrete.horarioHour,
        lembrete.horarioMinute,
      );
      final minutesLate = now.difference(scheduled).inMinutes;
      if (minutesLate < 0) continue;

      if (lembrete.status == LembreteStatus.perdido) {
        alerts.add(
          _buildMissedAlert(lembrete, now: now, minutesLate: minutesLate),
        );
        continue;
      }

      final threshold = _lateThresholdMinutes(lembrete);
      if (minutesLate >= threshold) {
        alerts.add(
          _buildLateAlert(lembrete, now: now, minutesLate: minutesLate),
        );
      }
    }

    final bpmAlert = _buildBpmAlert(bpm, now: now);
    if (bpmAlert != null) alerts.add(bpmAlert);

    alerts.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;
      return b.minutesLate.compareTo(a.minutesLate);
    });
    return alerts;
  }

  SmartAlert? _buildBpmAlert(int? bpm, {required DateTime now}) {
    if (bpm == null) return null;
    if (bpm >= 60 && bpm <= 100) return null;

    final isCritical = bpm < 50 || bpm > 120;
    final direction = bpm < 60 ? 'baixo' : 'alto';

    return SmartAlert(
      key: '${_dateKey(now)}:health:bpm:$direction',
      lembreteId: '',
      title: isCritical ? 'Batimento fora do padrão' : 'Atenção ao coração',
      message:
          'Última medição: $bpm BPM. Valor $direction para a faixa de repouso usada pelo app.',
      severity: isCritical
          ? SmartAlertSeverity.critical
          : SmartAlertSeverity.warning,
      createdAt: now,
      minutesLate: isCritical ? 9999 : 9998,
    );
  }

  SmartAlert _buildLateAlert(
    Lembrete lembrete, {
    required DateTime now,
    required int minutesLate,
  }) {
    final severity = _severityFor(lembrete);
    final category = _categoryLabel(lembrete.categoria);
    final title = severity == SmartAlertSeverity.critical
        ? 'Alerta crítico'
        : 'Lembrete atrasado';

    return SmartAlert(
      key: '${_dateKey(now)}:${lembrete.id}:late',
      lembreteId: lembrete.id,
      title: title,
      message:
          '$category "${lembrete.titulo}" está atrasado há ${_formatLate(minutesLate)}.',
      severity: severity,
      createdAt: now,
      minutesLate: minutesLate,
    );
  }

  SmartAlert _buildMissedAlert(
    Lembrete lembrete, {
    required DateTime now,
    required int minutesLate,
  }) {
    return SmartAlert(
      key: '${_dateKey(now)}:${lembrete.id}:missed',
      lembreteId: lembrete.id,
      title: 'Precisa de atenção',
      message:
          '${_categoryLabel(lembrete.categoria)} "${lembrete.titulo}" foi marcado como não feito.',
      severity: SmartAlertSeverity.critical,
      createdAt: now,
      minutesLate: minutesLate,
    );
  }

  int _lateThresholdMinutes(Lembrete lembrete) {
    if (lembrete.urgencia == 'critico') return 2;
    if (lembrete.urgencia == 'importante') return 10;
    if (lembrete.categoria == 'medicacao') return 15;
    return 30;
  }

  SmartAlertSeverity _severityFor(Lembrete lembrete) {
    if (lembrete.urgencia == 'critico') return SmartAlertSeverity.critical;
    if (lembrete.urgencia == 'importante' ||
        lembrete.categoria == 'medicacao') {
      return SmartAlertSeverity.warning;
    }
    return SmartAlertSeverity.info;
  }

  bool _isReminderActiveToday(Lembrete lembrete, DateTime now) {
    if (lembrete.recorrencia == 'diario' || lembrete.repeteTodosOsDias) {
      return true;
    }
    if (lembrete.recorrencia == 'semanal' || lembrete.recorrenciaSemanal) {
      return lembrete.diasSemana.contains(now.weekday);
    }
    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      return (lembrete.diaMes ?? lembrete.criadoEm.day) == now.day;
    }
    if (lembrete.recorrencia == 'quinzenal') {
      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(
            DateTime(
              lembrete.criadoEm.year,
              lembrete.criadoEm.month,
              lembrete.criadoEm.day,
            ),
          )
          .inDays;
      return diffDays >= 0 && diffDays % 15 == 0;
    }
    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      return _dateKey(lembrete.criadoEm) == _dateKey(now);
    }
    if (lembrete.recorrencia == 'intervalo' || lembrete.recorrenciaIntervalo) {
      return true;
    }
    return true;
  }

  Future<void> _notifyNewAlerts(List<SmartAlert> alerts) async {
    if (alerts.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notified = prefs.getStringList('smart_alert_notified_keys') ?? [];
    final notifiedSet = notified.toSet();
    var changed = false;

    for (final alert in alerts) {
      if (notifiedSet.contains(alert.key)) continue;
      await NotificationService.instance.mostrarAlertaCuidador(alert);
      notifiedSet.add(alert.key);
      changed = true;
    }

    if (changed) {
      await prefs.setStringList(
        'smart_alert_notified_keys',
        notifiedSet.take(200).toList(),
      );
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'medicacao':
        return 'Medicamento';
      case 'refeicoes':
        return 'Refeição';
      case 'hidratacao':
        return 'Água';
      case 'exercicio':
        return 'Exercício';
      default:
        return 'Lembrete';
    }
  }

  String _formatLate(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours h';
    return '$hours h $rest min';
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
