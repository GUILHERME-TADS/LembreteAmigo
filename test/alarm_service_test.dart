import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/alarm_service.dart';
import 'package:lembretes_app/main.dart';

void main() {
  setUp(() {
    AlarmService.instance.clearQueue();
  });

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

  test('enfileira segundo lembrete quando rota de alarme ja esta ativa', () {
    RouteTracker.instance.currentRouteName = '/active-reminder';

    AlarmService.instance.showOrEnqueueReminder('rem-1');
    AlarmService.instance.showOrEnqueueReminder('rem-2');

    expect(AlarmService.instance.pendingQueue, contains('rem-1'));
    expect(AlarmService.instance.pendingQueue, contains('rem-2'));
    expect(AlarmService.instance.pendingQueue.length, equals(2));

    // Nao duplica na fila
    AlarmService.instance.showOrEnqueueReminder('rem-1');
    expect(AlarmService.instance.pendingQueue.length, equals(2));

    RouteTracker.instance.currentRouteName = '/elderly-home';
  });
}
