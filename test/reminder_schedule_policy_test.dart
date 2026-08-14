import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/reminder_schedule_policy.dart';

void main() {
  group('ReminderSchedulePolicy', () {
    test('renova a assinatura a cada dia', () {
      final first = ReminderSchedulePolicy.fingerprint(
        reminderSignature: '{"id":"daily"}',
        now: DateTime(2026, 8, 13, 23, 59),
      );
      final next = ReminderSchedulePolicy.fingerprint(
        reminderSignature: '{"id":"daily"}',
        now: DateTime(2026, 8, 14),
      );

      expect(first, isNot(next));
    });

    test('reutiliza somente alarmes que continuam ativos no Android', () {
      expect(
        ReminderSchedulePolicy.canReuseSchedule(
          storedFingerprint: 'today|reminder',
          currentFingerprint: 'today|reminder',
          registeredAlarmIds: {10, 20},
          activeAlarmIds: {10, 20, 30},
        ),
        isTrue,
      );

      expect(
        ReminderSchedulePolicy.canReuseSchedule(
          storedFingerprint: 'today|reminder',
          currentFingerprint: 'today|reminder',
          registeredAlarmIds: {10, 20},
          activeAlarmIds: {10, 30},
        ),
        isFalse,
      );
    });

    test('nao confia em uma agenda vazia', () {
      expect(
        ReminderSchedulePolicy.canReuseSchedule(
          storedFingerprint: 'today|reminder',
          currentFingerprint: 'today|reminder',
          registeredAlarmIds: const {},
          activeAlarmIds: const {},
        ),
        isFalse,
      );
    });

    test('mantem a agenda futura de lembrete recorrente concluido', () {
      expect(
        ReminderSchedulePolicy.shouldCancelCompletedSchedule(
          completed: true,
          recurring: true,
        ),
        isFalse,
      );
      expect(
        ReminderSchedulePolicy.shouldCancelCompletedSchedule(
          completed: true,
          recurring: false,
        ),
        isTrue,
      );
    });
  });
}
