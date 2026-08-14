class VoiceReminderSchedule {
  final String recurrence;
  final DateTime startDate;
  final DateTime? endDate;
  final bool continuousUse;
  final bool repeatsEveryDay;
  final bool weekly;
  final bool monthly;
  final bool interval;
  final bool oneTime;

  const VoiceReminderSchedule({
    required this.recurrence,
    required this.startDate,
    required this.endDate,
    required this.continuousUse,
    required this.repeatsEveryDay,
    required this.weekly,
    required this.monthly,
    required this.interval,
    required this.oneTime,
  });
}

class VoiceReminderSchedulePolicy {
  static VoiceReminderSchedule resolve({
    required DateTime now,
    required int hour,
    required int minute,
    DateTime? parsedStartDate,
    String? parsedRecurrence,
  }) {
    final recurrence = _normalizeRecurrence(parsedRecurrence);
    final oneTime = recurrence == 'unico';
    var startDate = parsedStartDate == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(
            parsedStartDate.year,
            parsedStartDate.month,
            parsedStartDate.day,
          );

    if (oneTime && parsedStartDate == null) {
      final scheduledToday = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduledToday.isAfter(now)) {
        startDate = startDate.add(const Duration(days: 1));
      }
    }

    return VoiceReminderSchedule(
      recurrence: recurrence,
      startDate: startDate,
      endDate: oneTime ? startDate : null,
      continuousUse: !oneTime,
      repeatsEveryDay: recurrence == 'diario',
      weekly: recurrence == 'semanal',
      monthly: recurrence == 'mensal',
      interval: recurrence == 'intervalo',
      oneTime: oneTime,
    );
  }

  static String _normalizeRecurrence(String? value) {
    const supported = {
      'unico',
      'diario',
      'semanal',
      'mensal',
      'quinzenal',
      'intervalo',
    };
    final normalized = value?.trim().toLowerCase();
    return supported.contains(normalized) ? normalized! : 'unico';
  }
}
