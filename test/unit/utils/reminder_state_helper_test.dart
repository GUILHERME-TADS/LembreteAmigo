import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/utils/reminder_state_helper.dart';

void main() {
  group('ReminderStateHelper.nextReminder', () {
    final now = DateTime(2026, 7, 18, 15);

    test('mantem lembrete unico criado apos o horario como atrasado', () {
      final reminder = Lembrete(
        id: 'unico-atrasado',
        titulo: 'Lembrete unico',
        horarioHour: 10,
        horarioMinute: 0,
        criadoEm: DateTime(2026, 7, 18, 14),
        dataInicio: DateTime(2026, 7, 18),
        lembreteUnico: true,
        repeteTodosOsDias: false,
        recorrencia: 'unico',
      );

      expect(
        ReminderStateHelper.visualStatus(reminder, now: now),
        ReminderStatus.late,
      );
      expect(
        ReminderStateHelper.nextReminder([reminder], now: now),
        same(reminder),
      );
    });

    test('considera amanha para lembrete diario criado apos o horario', () {
      final reminder = Lembrete(
        id: 'diario',
        titulo: 'Lembrete diario',
        horarioHour: 10,
        horarioMinute: 0,
        criadoEm: DateTime(2026, 7, 18, 14),
      );

      expect(
        ReminderStateHelper.visualStatus(reminder, now: now),
        ReminderStatus.scheduled,
      );
      expect(
        ReminderStateHelper.nextReminder([reminder], now: now),
        same(reminder),
      );
    });

    test('prioriza o proximo horario futuro sobre um atrasado', () {
      final late = Lembrete(
        id: 'atrasado',
        titulo: 'Atrasado',
        horarioHour: 10,
        horarioMinute: 0,
        criadoEm: DateTime(2026, 7, 17),
      );
      final upcoming = Lembrete(
        id: 'proximo',
        titulo: 'Proximo',
        horarioHour: 16,
        horarioMinute: 0,
        criadoEm: DateTime(2026, 7, 17),
      );

      expect(
        ReminderStateHelper.nextReminder([late, upcoming], now: now),
        same(upcoming),
      );
    });
  });
}
