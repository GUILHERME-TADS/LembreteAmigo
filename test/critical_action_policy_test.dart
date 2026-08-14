import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/widgets/critical_action_guard.dart';

void main() {
  test('exige login quando a sessão tem mais de dez minutos', () {
    final now = DateTime(2026, 8, 13, 12);

    expect(
      CriticalActionGuard.needsRecentLogin(
        now.subtract(const Duration(minutes: 11)),
        now,
      ),
      isTrue,
    );
    expect(
      CriticalActionGuard.needsRecentLogin(
        now.subtract(const Duration(minutes: 5)),
        now,
      ),
      isFalse,
    );
    expect(CriticalActionGuard.needsRecentLogin(null, now), isTrue);
  });
}
