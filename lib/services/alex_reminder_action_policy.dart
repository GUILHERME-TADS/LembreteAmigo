import '../models/lembrete.dart';

class AlexReminderSelection {
  final Lembrete? reminder;
  final bool ambiguous;

  const AlexReminderSelection._({this.reminder, this.ambiguous = false});

  const AlexReminderSelection.found(Lembrete reminder)
    : this._(reminder: reminder);

  const AlexReminderSelection.none() : this._();

  const AlexReminderSelection.ambiguous() : this._(ambiguous: true);
}

class AlexReminderActionPolicy {
  static AlexReminderSelection selectActionable(
    Iterable<Lembrete> reminders, {
    required DateTime now,
    String command = '',
  }) {
    final candidates = reminders
        .map((reminder) => (reminder, _minutesFromOccurrence(reminder, now)))
        .where((entry) {
          final reminder = entry.$1;
          final delta = entry.$2;
          return delta != null &&
              delta >= -1 &&
              delta <= reminder.toleranciaMinutos &&
              reminder.isActiveOn(now) &&
              !reminder.concluido &&
              reminder.status != LembreteStatus.perdido &&
              reminder.status != LembreteStatus.precisaDeAjuda;
        })
        .toList();

    if (candidates.isEmpty) return const AlexReminderSelection.none();

    final commandTokens = _meaningfulTokens(command);
    final scored = candidates
        .map(
          (entry) => (
            entry.$1,
            entry.$2!,
            _meaningfulTokens(
              entry.$1.titulo,
            ).intersection(commandTokens).length,
          ),
        )
        .toList();
    final bestScore = scored
        .map((entry) => entry.$3)
        .reduce((a, b) => a > b ? a : b);
    final matching = bestScore > 0
        ? scored.where((entry) => entry.$3 == bestScore).toList()
        : scored;

    matching.sort((a, b) => a.$2.abs().compareTo(b.$2.abs()));
    if (matching.length > 1 && matching[0].$2.abs() == matching[1].$2.abs()) {
      return const AlexReminderSelection.ambiguous();
    }
    return AlexReminderSelection.found(matching.first.$1);
  }

  static int? _minutesFromOccurrence(Lembrete reminder, DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = reminder.horarioHour * 60 + reminder.horarioMinute;
    var occurrenceMinutes = startMinutes;

    if (reminder.recorrencia == 'intervalo' || reminder.recorrenciaIntervalo) {
      final intervalHours = (reminder.intervaloHoras ?? 4).clamp(1, 24).toInt();
      final diff = nowMinutes - startMinutes;
      if (diff >= 0) {
        occurrenceMinutes =
            startMinutes + (diff ~/ (intervalHours * 60)) * intervalHours * 60;
      }
    }

    return nowMinutes - occurrenceMinutes;
  }

  static Set<String> _meaningfulTokens(String value) {
    const ignored = {
      'alex',
      'agora',
      'ainda',
      'adiar',
      'depois',
      'feito',
      'fiz',
      'mais',
      'minuto',
      'minutos',
      'para',
      'pronto',
      'tomei',
    };
    return _normalize(value)
        .split(' ')
        .where((token) => token.length >= 3 && !ignored.contains(token))
        .toSet();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
