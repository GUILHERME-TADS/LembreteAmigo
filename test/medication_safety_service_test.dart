import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/medication_safety_service.dart';

void main() {
  Lembrete medication({
    required String id,
    required String title,
    required int hour,
    int minute = 0,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  }) {
    return Lembrete(
      id: id,
      titulo: title,
      horarioHour: hour,
      horarioMinute: minute,
      categoria: LembreteCategoria.medicacao,
      recorrencia: 'semanal',
      repeteTodosOsDias: days.length == 7,
      recorrenciaSemanal: days.length < 7,
      diasSemana: days,
    );
  }

  test('bloqueia o mesmo medicamento no mesmo horário e dias', () {
    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: 'Losartana',
      hour: 8,
      minute: 0,
      weekDays: const [1, 2, 3, 4, 5, 6, 7],
      existingReminders: [medication(id: 'a', title: 'LOSARTANA', hour: 8)],
    );

    expect(warnings, hasLength(1));
    expect(warnings.single.severity, MedicationSafetySeverity.critical);
  });

  test('avisa quando doses do mesmo medicamento estão muito próximas', () {
    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: 'Remédio Á',
      hour: 9,
      minute: 0,
      weekDays: const [1, 3, 5],
      existingReminders: [
        medication(id: 'a', title: 'Remedio A', hour: 8, days: const [1, 3, 5]),
      ],
    );

    expect(warnings.single.severity, MedicationSafetySeverity.warning);
  });

  test('não acusa conflito quando os dias não coincidem', () {
    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: 'Medicamento A',
      hour: 8,
      minute: 0,
      weekDays: const [2, 4],
      existingReminders: [
        medication(
          id: 'a',
          title: 'Medicamento A',
          hour: 8,
          days: const [1, 3, 5],
        ),
      ],
    );

    expect(warnings, isEmpty);
  });

  test('ignora o próprio lembrete durante edição', () {
    final existing = medication(id: 'a', title: 'Medicamento A', hour: 8);
    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: existing.titulo,
      hour: existing.horarioHour,
      minute: existing.horarioMinute,
      weekDays: existing.diasSemana,
      existingReminders: [existing],
      editingReminderId: existing.id,
    );

    expect(warnings, isEmpty);
  });

  test('não bloqueia lembretes únicos iguais em datas diferentes', () {
    final existing = Lembrete(
      id: 'one-time',
      titulo: 'Losartana',
      horarioHour: 8,
      horarioMinute: 0,
      categoria: LembreteCategoria.medicacao,
      recorrencia: 'unico',
      lembreteUnico: true,
      dataInicio: DateTime(2026, 8, 14),
      dataFim: DateTime(2026, 8, 14),
    );
    final candidateDate = DateTime(2026, 8, 13);

    final warnings = MedicationSafetyService.findScheduleConflicts(
      title: 'Losartana',
      hour: 8,
      minute: 0,
      weekDays: const [],
      existingReminders: [existing],
      startDate: candidateDate,
      endDate: candidateDate,
      oneTime: true,
    );

    expect(warnings, isEmpty);
  });
}
