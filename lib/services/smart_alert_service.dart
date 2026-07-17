import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/smart_alert.dart';
import 'crashlytics_service.dart';
import 'notification_service.dart';

class SmartAlertService {
  SmartAlertService._();
  static final SmartAlertService instance = SmartAlertService._();

  final ValueNotifier<List<SmartAlert>> notifier = ValueNotifier([]);

  List<SmartAlert> get alerts => List.unmodifiable(notifier.value);

  Future<void> atualizar(
    List<Lembrete> lembretes, {
    List<LembreteEvento>? eventos,
    DateTime? now,
  }) async {
    try {
      final detected = detectarAlertas(
        lembretes,
        eventos: eventos,
        now: now ?? DateTime.now(),
      );
      notifier.value = detected;
      await _notifyNewAlerts(detected);
    } catch (e, s) {
      debugPrint('[SmartAlert] Erro ao atualizar alertas: $e');
      CrashlyticsService.instance.recordError(e, s,
          reason: 'SmartAlertService.atualizar');
    }
  }

  List<SmartAlert> detectarAlertas(
    List<Lembrete> lembretes, {
    List<LembreteEvento>? eventos,
    required DateTime now,
  }) {
    final alerts = <SmartAlert>[];
    var lateCount = 0;
    var lateMedicationCount = 0;
    var criticalLateCount = 0;

    for (final lembrete in lembretes) {
      try {
        if (!_isReminderActiveToday(lembrete, now)) continue;
        if (lembrete.status.isConcluido) continue;

        final scheduled = DateTime(
          now.year,
          now.month,
          now.day,
          lembrete.horarioHour,
          lembrete.horarioMinute,
        );

        if (scheduled.isBefore(now) &&
            _isSameDay(lembrete.criadoEm, now) &&
            lembrete.criadoEm.isAfter(scheduled)) {
          continue;
        }

        final minutesLate = now.difference(scheduled).inMinutes;
        if (minutesLate < 0) continue;

        if (lembrete.status == LembreteStatus.perdido) {
          alerts.add(
            _buildMissedAlert(lembrete, now: now, minutesLate: minutesLate),
          );
          lateCount++;
          if (lembrete.categoria == 'medicacao') lateMedicationCount++;
          continue;
        }

        if (lembrete.status == LembreteStatus.precisaDeAjuda) {
          alerts.add(
            SmartAlert(
              key: 'needs_help_${lembrete.id}',
              lembreteId: lembrete.id,
              title: 'Idoso pediu ajuda',
              message: 'O idoso informou que precisa de ajuda com "${lembrete.titulo}".',
              severity: SmartAlertSeverity.critical,
              createdAt: now,
              minutesLate: minutesLate,
            ),
          );
          continue;
        }

        final threshold = _lateThresholdMinutes(lembrete);
        if (minutesLate >= threshold) {
          alerts.add(
            _buildLateAlert(lembrete, now: now, minutesLate: minutesLate),
          );
          lateCount++;
          if (lembrete.categoria == 'medicacao') lateMedicationCount++;
          if (_severityFor(lembrete) == SmartAlertSeverity.critical) {
            criticalLateCount++;
          }
        }
      } catch (e) {
        debugPrint('[SmartAlert] Erro ao processar lembrete ${lembrete.id}: $e');
      }
    }

    try {
      final routineAlert = _buildRoutinePatternAlert(
        now: now,
        lateCount: lateCount,
        lateMedicationCount: lateMedicationCount,
        criticalLateCount: criticalLateCount,
      );
      if (routineAlert != null) alerts.add(routineAlert);



      alerts.sort((a, b) {
        final severityCompare = b.severity.index.compareTo(a.severity.index);
        if (severityCompare != 0) return severityCompare;
        return b.minutesLate.compareTo(a.minutesLate);
      });
    } catch (e, s) {
      debugPrint('[SmartAlert] Erro ao construir alertas agregados: $e');
      CrashlyticsService.instance.recordError(e, s,
          reason: 'SmartAlertService.detectarAlertas');
    }

    return alerts;
  }

  SmartAlert? _buildRoutinePatternAlert({
    required DateTime now,
    required int lateCount,
    required int lateMedicationCount,
    required int criticalLateCount,
  }) {
    if (criticalLateCount >= 1) {
      return SmartAlert(
        key: '${_dateKey(now)}:pattern:critical',
        lembreteId: '',
        title: 'Rotina precisa de verificacao',
        message:
            'Ha lembrete critico sem resposta. Verifique o idoso ou acione outro cuidador.',
        severity: SmartAlertSeverity.critical,
        createdAt: now,
        minutesLate: 0,
      );
    }
    if (lateMedicationCount >= 2) {
      return SmartAlert(
        key: '${_dateKey(now)}:pattern:medication',
        lembreteId: '',
        title: 'Medicacoes acumuladas',
        message:
            '$lateMedicationCount lembretes de medicamento estao atrasados ou sem resposta hoje.',
        severity: SmartAlertSeverity.critical,
        createdAt: now,
        minutesLate: 10000,
      );
    }
    if (lateCount >= 3) {
      return SmartAlert(
        key: '${_dateKey(now)}:pattern:routine',
        lembreteId: '',
        title: 'Rotina fora do padrao',
        message:
            '$lateCount lembretes estao atrasados ou nao foram feitos hoje. Pode ser um sinal de dificuldade.',
        severity: SmartAlertSeverity.warning,
        createdAt: now,
        minutesLate: 9999,
      );
    }
    return null;
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
    final title = lembrete.titulo.toLowerCase();
    if (title.contains('insulina')) return 2;
    if (lembrete.categoria == 'medicacao') return 15;
    return 30;
  }

  SmartAlertSeverity _severityFor(Lembrete lembrete) {
    final title = lembrete.titulo.toLowerCase();
    if (title.contains('insulina')) {
      return SmartAlertSeverity.critical;
    }
    if (lembrete.categoria == 'medicacao') {
      return SmartAlertSeverity.warning;
    }
    return SmartAlertSeverity.info;
  }

  bool _isReminderActiveToday(Lembrete lembrete, DateTime now) =>
      Lembrete.isReminderActiveOn(lembrete, now);

  Future<void> _notifyNewAlerts(List<SmartAlert> alerts) async {
    if (alerts.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final notified = prefs.getStringList('smart_alert_notified_keys') ?? [];
      final notifiedSet = notified.toSet();
      var changed = false;

      for (final alert in alerts) {
        try {
          if (notifiedSet.contains(alert.key)) continue;
          await NotificationService.instance.mostrarAlertaCuidador(alert);
          notifiedSet.add(alert.key);
          changed = true;
        } catch (e) {
          debugPrint('[SmartAlert] Erro ao notificar alerta ${alert.key}: $e');
        }
      }

      if (changed) {
        await prefs.setStringList(
          'smart_alert_notified_keys',
          notifiedSet.take(200).toList(),
        );
      }
    } catch (e, s) {
      debugPrint('[SmartAlert] Erro ao persistir alertas notificados: $e');
      CrashlyticsService.instance.recordError(e, s,
          reason: 'SmartAlertService._notifyNewAlerts');
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
