class ReminderSchedulePolicy {
  const ReminderSchedulePolicy._();

  static String fingerprint({
    required String reminderSignature,
    required DateTime now,
  }) {
    final day =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '$day|$reminderSignature';
  }

  static bool canReuseSchedule({
    required String? storedFingerprint,
    required String currentFingerprint,
    required Set<int> registeredAlarmIds,
    required Set<int> activeAlarmIds,
  }) {
    if (storedFingerprint != currentFingerprint || registeredAlarmIds.isEmpty) {
      return false;
    }
    return registeredAlarmIds.every(activeAlarmIds.contains);
  }

  static bool shouldCancelCompletedSchedule({
    required bool completed,
    required bool recurring,
  }) {
    return completed && !recurring;
  }
}
