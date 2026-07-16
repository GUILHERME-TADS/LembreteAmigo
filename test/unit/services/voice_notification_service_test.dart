import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/voice_notification_service.dart';

void main() {
  setUp(() {
    VoiceNotificationService.instance.init();
  });

  test('init nao falha', () {
    expect(VoiceNotificationService.instance, isNotNull);
  });

  test('prefixForUrgency retorna prefixo critico', () {
    final service = VoiceNotificationService.instance;
    expect(service.prefixForUrgency('critico'), 'Alerta urgente!');
  });

  test('prefixForUrgency retorna prefixo importante', () {
    final service = VoiceNotificationService.instance;
    expect(service.prefixForUrgency('importante'), 'Aviso importante!');
  });

  test('prefixForUrgency retorna prefixo normal', () {
    final service = VoiceNotificationService.instance;
    expect(service.prefixForUrgency('normal'), 'Atenção!');
  });

  test('categoryName retorna nome para medicacao', () {
    final service = VoiceNotificationService.instance;
    expect(service.categoryName('medicacao'), 'do seu remédio');
  });

  test('categoryName retorna nome para hidratacao', () {
    final service = VoiceNotificationService.instance;
    expect(service.categoryName('hidratacao'), 'de beber água');
  });

  test('categoryName retorna nome para refeicoes', () {
    final service = VoiceNotificationService.instance;
    expect(service.categoryName('refeicoes'), 'de comer');
  });

  test('categoryName retorna nome para exercicio', () {
    final service = VoiceNotificationService.instance;
    expect(service.categoryName('exercicio'), 'do seu exercício');
  });

  test('categoryName retorna nome generico para categoria desconhecida', () {
    final service = VoiceNotificationService.instance;
    expect(service.categoryName('personalizado'), 'do seu lembrete');
  });
}
