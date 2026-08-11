import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/care_alert.dart';
import 'package:lembretes_app/models/emergency_card.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/models/wellbeing_entry.dart';
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

  group('dados offline', () {
    test('cartão de emergência preserva os campos no cache', () {
      final original = EmergencyCard(
        name: 'Maria',
        allergies: 'Dipirona',
        medications: const ['Medicamento A'],
        contactName: 'João',
        contactPhone: '11999999999',
        note: 'Usa marca-passo',
        updatedAt: DateTime.utc(2026, 8, 3, 12),
      );

      final restored = EmergencyCard.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.allergies, original.allergies);
      expect(restored.medications, original.medications);
      expect(restored.contactPhone, original.contactPhone);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('registro de bem-estar pode ser serializado localmente', () {
      final entry = WellbeingEntry(
        id: 'checkin-a',
        elderlyId: 'elderly-a',
        mood: 2,
        symptoms: const ['Dor'],
        note: 'Dor no joelho',
        transcript: 'Dor no joelho',
        needsHelp: true,
        createdAt: DateTime.utc(2026, 8, 3, 12),
        createdBy: 'elderly-a',
      );

      final restored = WellbeingEntry.fromMap(entry.id, entry.toLocalJson());

      expect(restored.mood, 2);
      expect(restored.symptoms, const ['Dor']);
      expect(restored.needsHelp, isTrue);
      expect(restored.createdAt, entry.createdAt);
    });
  });
}
