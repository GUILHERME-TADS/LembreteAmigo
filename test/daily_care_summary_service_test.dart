import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/models/lembrete_evento.dart';
import 'package:lembretes_app/services/daily_care_summary_service.dart';

void main() {
  test('resume atividades, medicamentos e estoque do dia', () {
    final now = DateTime(2026, 8, 13, 20);
    final reminders = [
      Lembrete(
        id: 'medicine',
        titulo: 'Medicamento A',
        horarioHour: 8,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
        medicamentoEstoque: 3,
        medicamentoEstoqueMinimo: 5,
      ),
      Lembrete(
        id: 'water',
        titulo: 'Beber água',
        horarioHour: 10,
        horarioMinute: 0,
        categoria: LembreteCategoria.hidratacao,
      ),
    ];
    final events = [
      LembreteEvento(
        id: 'confirm-medicine',
        lembreteId: 'medicine',
        titulo: 'Medicamento A',
        categoria: LembreteCategoria.medicacao,
        status: LembreteStatus.concluido,
        registradoEm: DateTime(2026, 8, 13, 8, 2),
      ),
      LembreteEvento(
        id: 'help-water',
        lembreteId: 'water',
        titulo: 'Beber água',
        categoria: LembreteCategoria.hidratacao,
        status: LembreteStatus.precisaDeAjuda,
        registradoEm: DateTime(2026, 8, 13, 10, 10),
      ),
    ];

    final summary = DailyCareSummaryService.build(
      reminders: reminders,
      events: events,
      now: now,
    );

    expect(summary.scheduled, 2);
    expect(summary.completed, 1);
    expect(summary.needsHelp, 1);
    expect(summary.medicationsCompleted, 1);
    expect(summary.lowStockMedications, 1);
    expect(summary.adherence, 0.5);
    expect(summary.needsAttention, isTrue);
  });

  test('ignora eventos corrigidos e eventos de outro dia', () {
    final now = DateTime(2026, 8, 13, 20);
    final reminder = Lembrete(
      id: 'meal',
      titulo: 'Almoço',
      horarioHour: 12,
      horarioMinute: 0,
      categoria: LembreteCategoria.refeicoes,
    );
    final events = [
      LembreteEvento(
        id: 'old-confirmation',
        lembreteId: reminder.id,
        titulo: reminder.titulo,
        categoria: reminder.categoria,
        status: LembreteStatus.concluido,
        registradoEm: DateTime(2026, 8, 12, 12),
      ),
      LembreteEvento(
        id: 'undo',
        lembreteId: reminder.id,
        titulo: reminder.titulo,
        categoria: reminder.categoria,
        status: LembreteStatus.pendente,
        corrigeEventoId: 'confirm-today',
        registradoEm: DateTime(2026, 8, 13, 12, 5),
      ),
      LembreteEvento(
        id: 'confirm-today',
        lembreteId: reminder.id,
        titulo: reminder.titulo,
        categoria: reminder.categoria,
        status: LembreteStatus.concluido,
        registradoEm: DateTime(2026, 8, 13, 12),
      ),
    ];

    final summary = DailyCareSummaryService.build(
      reminders: [reminder],
      events: events,
      now: now,
    );

    expect(summary.completed, 0);
    expect(summary.pending, 1);
  });
}
