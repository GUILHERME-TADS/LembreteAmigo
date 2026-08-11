import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/utils/reminder_occurrence_helper.dart';

void main() {
  group('ReminderOccurrenceHelper', () {
    test('gera a mesma chave para a mesma ocorrencia diaria', () {
      final reminder = Lembrete(
        id: 'reminder-1',
        titulo: 'Beber agua',
        horarioHour: 8,
        horarioMinute: 30,
      );

      final first = ReminderOccurrenceHelper.key(
        reminder,
        now: DateTime(2026, 8, 3, 8, 31),
      );
      final retry = ReminderOccurrenceHelper.key(
        reminder,
        now: DateTime(2026, 8, 3, 20),
      );

      expect(first, 'reminder-1_20260803_0830');
      expect(retry, first);
      expect(
        ReminderOccurrenceHelper.completionEventId(first),
        'confirm_$first',
      );
      expect(ReminderOccurrenceHelper.undoEventId(first), 'undo_$first');
      expect(ReminderOccurrenceHelper.dateKeyFromOccurrence(first), '20260803');
    });

    test('separa cada janela de um lembrete por intervalo', () {
      final reminder = Lembrete(
        id: 'interval-reminder',
        titulo: 'Tomar agua',
        horarioHour: 6,
        horarioMinute: 0,
        recorrenciaIntervalo: true,
        intervaloHoras: 4,
        recorrencia: 'intervalo',
      );

      expect(
        ReminderOccurrenceHelper.key(
          reminder,
          now: DateTime(2026, 8, 3, 13, 59),
        ),
        'interval-reminder_20260803_1000',
      );
      expect(
        ReminderOccurrenceHelper.key(reminder, now: DateTime(2026, 8, 3, 14)),
        'interval-reminder_20260803_1400',
      );
    });

    test('usa padroes de seguranca adequados por categoria', () {
      final medication = Lembrete(
        id: 'medication',
        titulo: 'Tomar remedio',
        horarioHour: 9,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
      );
      final hydration = Lembrete(
        id: 'hydration',
        titulo: 'Beber agua',
        horarioHour: 10,
        horarioMinute: 0,
        categoria: LembreteCategoria.hidratacao,
      );

      expect(medication.modoConfirmacao, LembreteModoConfirmacao.foto);
      expect(medication.toleranciaMinutos, 15);
      expect(hydration.modoConfirmacao, LembreteModoConfirmacao.simples);
      expect(hydration.toleranciaMinutos, 30);
      expect(hydration.opcoesAdiamentoMinutos, [5, 10, 15]);
    });
  });
}
