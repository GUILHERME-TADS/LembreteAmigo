import '../models/lembrete.dart';

class ReminderOccurrenceHelper {
  ReminderOccurrenceHelper._();

  static String key(Lembrete reminder, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final baseMinutes =
        (reminder.originalHorarioHour ?? reminder.horarioHour) * 60 +
        (reminder.originalHorarioMinute ?? reminder.horarioMinute);
    var occurrenceMinutes = baseMinutes;

    if (reminder.recorrenciaIntervalo || reminder.recorrencia == 'intervalo') {
      final intervalMinutes = (reminder.intervaloHoras ?? 4).clamp(1, 24) * 60;
      final currentMinutes = current.hour * 60 + current.minute;
      final difference = currentMinutes - baseMinutes;
      if (difference >= 0) {
        occurrenceMinutes =
            baseMinutes + (difference ~/ intervalMinutes) * intervalMinutes;
      }
    }

    final hour = (occurrenceMinutes ~/ 60) % 24;
    final minute = occurrenceMinutes % 60;
    return '${reminder.id}_${dateKey(current)}_'
        '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}';
  }

  static String completionEventId(String occurrenceKey) =>
      'confirm_$occurrenceKey';

  static String undoEventId(String occurrenceKey) => 'undo_$occurrenceKey';

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String? dateKeyFromOccurrence(String occurrenceKey) {
    if (occurrenceKey.length < 13) return null;
    final candidate = occurrenceKey.substring(
      occurrenceKey.length - 13,
      occurrenceKey.length - 5,
    );
    return RegExp(r'^\d{8}$').hasMatch(candidate) ? candidate : null;
  }
}
