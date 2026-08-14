import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/utils/voice_reminder_schedule_policy.dart';

void main() {
  test('agenda para amanhã quando horário único sem data já passou', () {
    final schedule = VoiceReminderSchedulePolicy.resolve(
      now: DateTime(2026, 8, 14, 18, 30),
      hour: 8,
      minute: 0,
    );

    expect(schedule.startDate, DateTime(2026, 8, 15));
    expect(schedule.endDate, DateTime(2026, 8, 15));
    expect(schedule.oneTime, isTrue);
    expect(schedule.repeatsEveryDay, isFalse);
    expect(schedule.continuousUse, isFalse);
  });

  test('mantém hoje quando horário único ainda está no futuro', () {
    final schedule = VoiceReminderSchedulePolicy.resolve(
      now: DateTime(2026, 8, 14, 7, 30),
      hour: 8,
      minute: 0,
    );

    expect(schedule.startDate, DateTime(2026, 8, 14));
  });

  test('preserva data falada explicitamente', () {
    final schedule = VoiceReminderSchedulePolicy.resolve(
      now: DateTime(2026, 8, 14, 18, 30),
      hour: 8,
      minute: 0,
      parsedStartDate: DateTime(2026, 8, 20),
      parsedRecurrence: 'unico',
    );

    expect(schedule.startDate, DateTime(2026, 8, 20));
  });

  test('mapeia repetição diária sem sinalizar lembrete único', () {
    final schedule = VoiceReminderSchedulePolicy.resolve(
      now: DateTime(2026, 8, 14, 18, 30),
      hour: 8,
      minute: 0,
      parsedRecurrence: 'diario',
    );

    expect(schedule.startDate, DateTime(2026, 8, 14));
    expect(schedule.endDate, isNull);
    expect(schedule.oneTime, isFalse);
    expect(schedule.repeatsEveryDay, isTrue);
    expect(schedule.continuousUse, isTrue);
  });
}
