import '../models/lembrete.dart';

enum ReminderStatus {
  done,
  doneWithPhoto,
  caregiverConfirmed,
  late,
  scheduled,
  postponed,
  missed,
  needsHelp,
}

class ReminderStateHelper {
  static bool isActiveToday(Lembrete lembrete, {DateTime? now}) =>
      lembrete.isActiveOn(now ?? DateTime.now());

  static List<Lembrete> activeTodaySorted(
    Iterable<Lembrete> lembretes, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final list = lembretes
        .where((lembrete) => isActiveToday(lembrete, now: currentTime))
        .toList();
    list.sort(compareByTime);
    return list;
  }

  static int compareByTime(Lembrete a, Lembrete b) {
    final aMin = a.horarioHour * 60 + a.horarioMinute;
    final bMin = b.horarioHour * 60 + b.horarioMinute;
    return aMin.compareTo(bMin);
  }

  static ReminderStatus storedStatus(Lembrete lembrete) {
    switch (lembrete.status) {
      case LembreteStatus.adiado:
        return ReminderStatus.postponed;
      case LembreteStatus.perdido:
        return ReminderStatus.missed;
      case LembreteStatus.precisaDeAjuda:
        return ReminderStatus.needsHelp;
      case LembreteStatus.concluido:
        return ReminderStatus.done;
      case LembreteStatus.concluidoComFoto:
        return ReminderStatus.doneWithPhoto;
      case LembreteStatus.confirmadoPeloCuidador:
        return ReminderStatus.caregiverConfirmed;
      case LembreteStatus.pendente:
        return ReminderStatus.scheduled;
    }
  }

  static ReminderStatus visualStatus(Lembrete lembrete, {DateTime? now}) {
    final stored = storedStatus(lembrete);
    if (stored != ReminderStatus.scheduled || lembrete.concluido) {
      return stored;
    }

    final currentTime = now ?? DateTime.now();
    var targetTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );

    final tomorrow = currentTime.add(const Duration(days: 1));
    final hasNextOccurrence = lembrete.isActiveOn(tomorrow);

    if (targetTime.isBefore(currentTime) &&
        lembrete.criadoEm.isAfter(targetTime) &&
        hasNextOccurrence) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    final diff = targetTime.difference(currentTime);
    if (diff.isNegative && diff.inMinutes.abs() >= 5) {
      return ReminderStatus.late;
    }

    return stored;
  }

  static Lembrete? nextReminder(Iterable<Lembrete> lembretes, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final today = activeTodaySorted(lembretes, now: currentTime);
    if (today.isEmpty) return null;

    final nowMinutes = currentTime.hour * 60 + currentTime.minute;
    for (final lembrete in today) {
      final visual = visualStatus(lembrete, now: currentTime);
      final reminderMinutes =
          lembrete.horarioHour * 60 + lembrete.horarioMinute;
      if (visual == ReminderStatus.scheduled && reminderMinutes >= nowMinutes) {
        return lembrete;
      }
    }

    for (final lembrete in today) {
      final visual = visualStatus(lembrete, now: currentTime);
      if (visual == ReminderStatus.late || visual == ReminderStatus.scheduled) {
        return lembrete;
      }
    }

    return null;
  }
}

ReminderStatus reminderStatusFromLembrete(Lembrete lembrete) =>
    ReminderStateHelper.storedStatus(lembrete);

ReminderStatus reminderVisualStatusFromLembrete(
  Lembrete lembrete, {
  DateTime? now,
}) => ReminderStateHelper.visualStatus(lembrete, now: now);
