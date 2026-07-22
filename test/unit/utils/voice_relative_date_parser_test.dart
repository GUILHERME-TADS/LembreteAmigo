import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/utils/voice_reminder_parser.dart';

void main() {
  group('VoiceReminderParser - Relative Dates & Weekdays', () {
    test('extrai horario e data de amanha', () {
      final res = VoiceReminderParser.parse('Consulta no medico amanha as 10 horas');
      expect(res, isNotNull);
      expect(res!.hour, 10);
      expect(res.minute, 0);
      expect(res.dataInicio, isNotNull);

      final now = DateTime.now();
      final expectedTomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      expect(res.dataInicio!.year, expectedTomorrow.year);
      expect(res.dataInicio!.month, expectedTomorrow.month);
      expect(res.dataInicio!.day, expectedTomorrow.day);
      expect(res.title.contains('amanha'), false);
    });

    test('extrai dia da semana especifico (proxima terca)', () {
      final res = VoiceReminderParser.parse('Exame de sangue na proxima terca-feira as 14:30');
      expect(res, isNotNull);
      expect(res!.hour, 14);
      expect(res.minute, 30);
      expect(res.dataInicio, isNotNull);
      expect(res.dataInicio!.weekday, DateTime.tuesday);
      expect(res.title.contains('terca'), false);
    });

    test('extrai recorrencia semanal para toda quinta', () {
      final res = VoiceReminderParser.parse('Fisioterapia toda quinta-feira as 9 da manha');
      expect(res, isNotNull);
      expect(res!.hour, 9);
      expect(res.minute, 0);
      expect(res.recorrencia, 'semanal');
      expect(res.diasSemana, contains(DateTime.thursday));
    });
  });
}
