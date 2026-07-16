import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/utils/debounce.dart';

void main() {
  group('Debouncer', () {
    test('executes callback after delay', () async {
      final debouncer = Debouncer(delay: Duration.zero);
      var executed = false;

      debouncer.call(() {
        executed = true;
      });

      await Future(() {});
      expect(executed, isTrue);
      debouncer.dispose();
    });

    test('cancels previous call on new call', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var counter = 0;

      debouncer.call(() => counter++);
      debouncer.call(() => counter++);
      debouncer.call(() => counter++);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(counter, equals(1));
      debouncer.dispose();
    });

    test('dispose cancels pending', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var executed = false;

      debouncer.call(() => executed = true);
      debouncer.dispose();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(executed, isFalse);
    });
  });

  group('Throttler', () {
    test('allows first call immediately', () {
      final throttler = Throttler(interval: const Duration(seconds: 1));
      var counter = 0;

      throttler.call(() => counter++);
      expect(counter, equals(1));
    });

    test('blocks subsequent calls within delay', () {
      final throttler = Throttler(interval: const Duration(seconds: 1));
      var counter = 0;

      throttler.call(() => counter++);
      throttler.call(() => counter++);
      expect(counter, equals(1));
    });

    test('allows call after delay', () async {
      final throttler = Throttler(interval: Duration.zero);
      var counter = 0;

      throttler.call(() => counter++);
      await Future(() {});
      throttler.call(() => counter++);
      expect(counter, equals(2));
    });
  });
}
