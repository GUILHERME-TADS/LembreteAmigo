import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/alarm_service.dart';

void main() {
  test('permite agendar lembretes distintos no mesmo segundo', () {
    final reminder = Lembrete(
      id: 'same-time',
      titulo: 'Tomar medicamento',
      horarioHour: 8,
      horarioMinute: 0,
    );

    final settings = AlarmService.instance.buildReminderAlarmSettings(
      lembrete: reminder,
      date: DateTime(2026, 8, 15, 8),
      audioPath: 'assets/remedio.mp3',
      id: 123,
    );

    expect(settings.allowSameSecondScheduling, isTrue);
    expect(settings.allowAlarmOverlap, isFalse);
  });
}
