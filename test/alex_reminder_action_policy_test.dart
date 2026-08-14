import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/alex_reminder_action_policy.dart';

void main() {
  Lembrete reminder({
    required String id,
    required String title,
    int hour = 9,
    int minute = 0,
    int tolerance = 15,
  }) {
    return Lembrete(
      id: id,
      titulo: title,
      horarioHour: hour,
      horarioMinute: minute,
      toleranciaMinutos: tolerance,
      recorrencia: 'diario',
    );
  }

  test('não altera lembrete futuro fora da janela', () {
    final result = AlexReminderActionPolicy.selectActionable(
      [reminder(id: 'future', title: 'Tomar vitamina', hour: 10)],
      now: DateTime(2026, 8, 14, 9),
      command: 'já tomei',
    );

    expect(result.reminder, isNull);
    expect(result.ambiguous, isFalse);
  });

  test('seleciona pelo título quando dois lembretes estão no horário', () {
    final result = AlexReminderActionPolicy.selectActionable(
      [
        reminder(id: 'water', title: 'Beber água'),
        reminder(id: 'medicine', title: 'Tomar losartana'),
      ],
      now: DateTime(2026, 8, 14, 9, 5),
      command: 'já tomei a losartana',
    );

    expect(result.reminder?.id, 'medicine');
    expect(result.ambiguous, isFalse);
  });

  test('pede esclarecimento quando há empate sem nome', () {
    final result = AlexReminderActionPolicy.selectActionable(
      [
        reminder(id: 'water', title: 'Beber água'),
        reminder(id: 'medicine', title: 'Tomar losartana'),
      ],
      now: DateTime(2026, 8, 14, 9, 5),
      command: 'já fiz',
    );

    expect(result.reminder, isNull);
    expect(result.ambiguous, isTrue);
  });

  test('usa a ocorrência mais recente para lembrete por intervalo', () {
    final intervalReminder = Lembrete(
      id: 'water',
      titulo: 'Beber água',
      horarioHour: 8,
      horarioMinute: 0,
      recorrencia: 'intervalo',
      recorrenciaIntervalo: true,
      intervaloHoras: 2,
      toleranciaMinutos: 15,
    );

    final result = AlexReminderActionPolicy.selectActionable(
      [intervalReminder],
      now: DateTime(2026, 8, 14, 12, 10),
      command: 'já bebi a água',
    );

    expect(result.reminder?.id, 'water');
  });
}
