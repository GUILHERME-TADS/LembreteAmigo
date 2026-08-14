import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/alex_ai_service.dart';

void main() {
  setUp(() => AlexAIService.instance.clearHistory());

  test('emergência tem prioridade sobre conclusão', () async {
    final response = await AlexAIService.instance.processMessage(
      'Alex, socorro, eu já tomei o remédio',
    );

    expect(response.isEmergency, isTrue);
    expect(response.isCompleteReminder, isFalse);
  });

  test('negação não conclui lembrete', () async {
    final response = await AlexAIService.instance.processMessage(
      'Eu ainda não tomei o remédio',
    );

    expect(response.isCompleteReminder, isFalse);
  });

  test('frase afirmativa identifica conclusão', () async {
    final response = await AlexAIService.instance.processMessage(
      'Já tomei a losartana',
    );

    expect(response.isCompleteReminder, isTrue);
  });

  test('palavra normal não é confundida com mal-estar', () async {
    final response = await AlexAIService.instance.processMessage(
      'Está tudo normal',
    );

    expect(response.isEmergency, isFalse);
  });
}
