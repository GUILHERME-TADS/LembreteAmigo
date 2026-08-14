import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/lembrete.dart';

enum MedicationSafetySeverity { notice, warning, critical }

@immutable
class MedicationSafetyWarning {
  final MedicationSafetySeverity severity;
  final String title;
  final String message;
  final String reminderId;

  const MedicationSafetyWarning({
    required this.severity,
    required this.title,
    required this.message,
    required this.reminderId,
  });
}

class MedicationSafetyService {
  const MedicationSafetyService._();

  static List<MedicationSafetyWarning> findScheduleConflicts({
    required String title,
    required int hour,
    required int minute,
    required Iterable<int> weekDays,
    required Iterable<Lembrete> existingReminders,
    String? editingReminderId,
    DateTime? startDate,
    DateTime? endDate,
    bool oneTime = false,
    int nearDoseWindowMinutes = 120,
  }) {
    final normalizedTitle = _normalize(title);
    final candidateDays = weekDays.toSet();
    final candidateMinute = hour * 60 + minute;
    final warnings = <MedicationSafetyWarning>[];

    for (final existing in existingReminders) {
      if (existing.id == editingReminderId ||
          LembreteCategoria.normalizar(existing.categoria) !=
              LembreteCategoria.medicacao ||
          !_schedulesOverlap(
            candidateDays: candidateDays,
            candidateStart: startDate,
            candidateEnd: endDate,
            candidateOneTime: oneTime,
            existing: existing,
          )) {
        continue;
      }

      final distance = _clockDistance(
        candidateMinute,
        existing.horarioHour * 60 + existing.horarioMinute,
      );
      final sameMedication = _normalize(existing.titulo) == normalizedTitle;

      if (sameMedication && distance == 0) {
        warnings.add(
          MedicationSafetyWarning(
            severity: MedicationSafetySeverity.critical,
            title: 'Possível dose duplicada',
            message:
                '${existing.titulo} já está programado para ${existing.horarioFormatado} nos mesmos dias.',
            reminderId: existing.id,
          ),
        );
      } else if (sameMedication && distance <= nearDoseWindowMinutes) {
        warnings.add(
          MedicationSafetyWarning(
            severity: MedicationSafetySeverity.warning,
            title: 'Doses muito próximas',
            message:
                '${existing.titulo} já está marcado para ${existing.horarioFormatado}, com apenas $distance minuto(s) de diferença.',
            reminderId: existing.id,
          ),
        );
      } else if (!sameMedication && distance == 0) {
        warnings.add(
          MedicationSafetyWarning(
            severity: MedicationSafetySeverity.notice,
            title: 'Medicamentos no mesmo horário',
            message:
                '${existing.titulo} também está programado para ${existing.horarioFormatado}. Confira se essa combinação foi orientada.',
            reminderId: existing.id,
          ),
        );
      }
    }

    warnings.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return warnings;
  }

  static bool _schedulesOverlap({
    required Set<int> candidateDays,
    required DateTime? candidateStart,
    required DateTime? candidateEnd,
    required bool candidateOneTime,
    required Lembrete existing,
  }) {
    final existingOneTime =
        existing.recorrencia == 'unico' || existing.lembreteUnico;
    final existingStart = existing.dataInicio ?? existing.criadoEm;
    final existingEnd =
        existing.dataFim ?? (existingOneTime ? existingStart : null);

    if (!_dateRangesOverlap(
      candidateStart,
      candidateEnd,
      existingStart,
      existingEnd,
    )) {
      return false;
    }

    if (candidateOneTime && candidateStart != null) {
      return Lembrete.isReminderActiveOn(existing, candidateStart);
    }
    if (existingOneTime) {
      final date = existing.dataInicio ?? existing.criadoEm;
      final afterStart =
          candidateStart == null ||
          !_dateOnly(date).isBefore(_dateOnly(candidateStart));
      final beforeEnd =
          candidateEnd == null ||
          !_dateOnly(date).isAfter(_dateOnly(candidateEnd));
      final matchingWeekday =
          candidateDays.isEmpty || candidateDays.contains(date.weekday);
      return afterStart && beforeEnd && matchingWeekday;
    }

    final existingDays = existing.diasSemana.toSet();
    final candidateDaily = candidateDays.isEmpty || candidateDays.length == 7;
    final existingDaily =
        existing.recorrencia == 'diario' ||
        existing.repeteTodosOsDias ||
        existingDays.isEmpty;
    if (candidateDaily || existingDaily) return true;
    return candidateDays.intersection(existingDays).isNotEmpty;
  }

  static bool _dateRangesOverlap(
    DateTime? firstStart,
    DateTime? firstEnd,
    DateTime? secondStart,
    DateTime? secondEnd,
  ) {
    if (firstStart != null &&
        secondEnd != null &&
        _dateOnly(secondEnd).isBefore(_dateOnly(firstStart))) {
      return false;
    }
    if (secondStart != null &&
        firstEnd != null &&
        _dateOnly(firstEnd).isBefore(_dateOnly(secondStart))) {
      return false;
    }
    return true;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _clockDistance(int a, int b) {
    final direct = (a - b).abs();
    return min(direct, 24 * 60 - direct);
  }

  static String _normalize(String input) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    var value = input.trim().toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      value = value.replaceAll(accents[i], plain[i]);
    }
    return value.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
