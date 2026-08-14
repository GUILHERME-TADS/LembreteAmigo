import '../models/daily_care_summary.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';

class DailyCareSummaryService {
  const DailyCareSummaryService._();

  static DailyCareSummary build({
    required Iterable<Lembrete> reminders,
    required Iterable<LembreteEvento> events,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final active = reminders
        .where((reminder) => Lembrete.isReminderActiveOn(reminder, today))
        .toList(growable: false);
    final correctedIds = events
        .map((event) => event.corrigeEventoId)
        .whereType<String>()
        .toSet();
    final latestByReminder = <String, LembreteEvento>{};

    for (final event in events) {
      if (!_sameDay(event.registradoEm, today) ||
          event.corrigeEventoId != null ||
          correctedIds.contains(event.id)) {
        continue;
      }
      final previous = latestByReminder[event.lembreteId];
      if (previous == null ||
          event.registradoEm.isAfter(previous.registradoEm)) {
        latestByReminder[event.lembreteId] = event;
      }
    }

    var completed = 0;
    var pending = 0;
    var postponed = 0;
    var missed = 0;
    var needsHelp = 0;
    var medications = 0;
    var medicationsCompleted = 0;
    var lowStock = 0;

    for (final reminder in active) {
      final status = latestByReminder[reminder.id]?.status ?? reminder.status;
      final isMedication =
          LembreteCategoria.normalizar(reminder.categoria) ==
          LembreteCategoria.medicacao;
      if (isMedication) {
        medications++;
        final stock = reminder.medicamentoEstoque;
        final minimum = reminder.medicamentoEstoqueMinimo;
        if (stock != null && minimum != null && stock <= minimum) lowStock++;
      }

      if (status.isConcluido) {
        completed++;
        if (isMedication) medicationsCompleted++;
      } else {
        switch (status) {
          case LembreteStatus.adiado:
            postponed++;
          case LembreteStatus.perdido:
            missed++;
          case LembreteStatus.precisaDeAjuda:
            needsHelp++;
          default:
            pending++;
        }
      }
    }

    return DailyCareSummary(
      scheduled: active.length,
      completed: completed,
      pending: pending,
      postponed: postponed,
      missed: missed,
      needsHelp: needsHelp,
      medications: medications,
      medicationsCompleted: medicationsCompleted,
      lowStockMedications: lowStock,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
