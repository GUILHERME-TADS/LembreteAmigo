import 'package:flutter/foundation.dart';

class AudioManager {
  AudioManager._();

  static final _activeIdNotifier = ValueNotifier<int?>(null);
  static int _nextId = 0;

  static ValueNotifier<int?> get activeIdNotifier => _activeIdNotifier;

  static int generateId() {
    final id = _nextId;
    _nextId++;
    return id;
  }

  static bool requestPlay(int id) {
    if (_activeIdNotifier.value == id) return false;
    _activeIdNotifier.value = id;
    return true;
  }

  static void stopPlay(int id) {
    if (_activeIdNotifier.value == id) {
      _activeIdNotifier.value = null;
    }
  }

  static void stopAll() {
    _activeIdNotifier.value = null;
  }
}
