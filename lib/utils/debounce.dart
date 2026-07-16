import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

class Throttler {
  final Duration interval;
  DateTime? _lastCall;
  Timer? _timer;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) >= interval) {
      _lastCall = now;
      action();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
