enum ReminderCompletionOutcome {
  completed,
  alreadyCompleted,
  requiresPhoto,
  requiresCaregiver,
  undone,
  undoExpired,
  failed,
}

class ReminderCompletionResult {
  final ReminderCompletionOutcome outcome;
  final String message;
  final String? eventId;
  final DateTime? registeredAt;

  const ReminderCompletionResult({
    required this.outcome,
    required this.message,
    this.eventId,
    this.registeredAt,
  });

  bool get succeeded =>
      outcome == ReminderCompletionOutcome.completed ||
      outcome == ReminderCompletionOutcome.undone;
}
