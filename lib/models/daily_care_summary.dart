class DailyCareSummary {
  final int scheduled;
  final int completed;
  final int pending;
  final int postponed;
  final int missed;
  final int needsHelp;
  final int medications;
  final int medicationsCompleted;
  final int lowStockMedications;

  const DailyCareSummary({
    required this.scheduled,
    required this.completed,
    required this.pending,
    required this.postponed,
    required this.missed,
    required this.needsHelp,
    required this.medications,
    required this.medicationsCompleted,
    required this.lowStockMedications,
  });

  double get adherence => scheduled == 0 ? 1 : completed / scheduled;
  bool get needsAttention =>
      missed > 0 || needsHelp > 0 || lowStockMedications > 0;

  String get headline {
    if (scheduled == 0) {
      return 'Nenhuma atividade prevista para hoje.';
    }
    if (needsHelp > 0) {
      return '$needsHelp pedido(s) de ajuda aguardando atenção.';
    }
    if (missed > 0) {
      return '$missed atividade(s) não foram realizadas.';
    }
    if (pending == 0 && postponed == 0) {
      return 'Tudo foi concluído hoje.';
    }
    return '$completed de $scheduled atividades concluídas.';
  }
}
