enum SmartAlertSeverity { info, warning, critical }

class SmartAlert {
  final String key;
  final String lembreteId;
  final String title;
  final String message;
  final SmartAlertSeverity severity;
  final DateTime createdAt;
  final int minutesLate;

  const SmartAlert({
    required this.key,
    required this.lembreteId,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.minutesLate,
  });
}
