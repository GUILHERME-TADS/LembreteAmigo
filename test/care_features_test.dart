import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/care_alert.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/stock_service.dart';

void main() {
  group('central de pendências', () {
    test('interpreta alerta assumido e mantém responsável', () {
      final alert = CareAlert.fromMap('alert-a', {
        'idosoId': 'elderly-a',
        'tipo': 'missed_reminder',
        'titulo': 'Lembrete sem resposta',
        'mensagem': 'O medicamento está atrasado.',
        'severidade': 3,
        'status': 'acknowledged',
        'responsavelId': 'caregiver-a',
        'createdAt': '2026-08-03T10:30:00.000Z',
      });

      expect(alert.isAcknowledged, isTrue);
      expect(alert.isOpen, isFalse);
      expect(alert.responsibleId, 'caregiver-a');
      expect(alert.severity, 3);
    });
  });

  group('previsão de estoque', () {
    test('estima consumo diário para lembrete por intervalo', () {
      final reminder = Lembrete(
        id: 'medicine-a',
        titulo: 'Medicamento A',
        horarioHour: 8,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
        recorrencia: 'intervalo',
        intervaloHoras: 8,
        medicamentoUnidadesPorDose: 2,
        medicamentoEstoque: 30,
      );

      expect(StockService.instance.estimatedDailyConsumption(reminder), 6);
      expect(StockService.instance.estimatedDaysRemaining(reminder), 5);
    });

    test('estima consumo semanal proporcional aos dias escolhidos', () {
      final reminder = Lembrete(
        id: 'medicine-weekly',
        titulo: 'Medicamento semanal',
        horarioHour: 8,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
        recorrencia: 'semanal',
        diasSemana: const [1, 3, 5],
        medicamentoUnidadesPorDose: 1,
        medicamentoEstoque: 6,
      );

      expect(
        StockService.instance.estimatedDailyConsumption(reminder),
        closeTo(3 / 7, 0.0001),
      );
      expect(StockService.instance.estimatedDaysRemaining(reminder), 14);
    });
  });
}
