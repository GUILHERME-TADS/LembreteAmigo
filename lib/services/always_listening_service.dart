import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_service.dart';
import '../services/alex_ai_service.dart';

enum ListeningState { paused, listening, processing, sleeping }

class AlwaysListeningService {
  AlwaysListeningService._();
  static final AlwaysListeningService instance =
      AlwaysListeningService._();

  final ValueNotifier<ListeningState> state =
      ValueNotifier(ListeningState.sleeping);
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  stt.SpeechToText? _speech;
  Timer? _listenTimer;
  Timer? _pauseTimer;
  bool _initialized = false;
  bool _isListening = false;

  static const Duration _listenDuration = Duration(seconds: 30);
  static const Duration _pauseDuration = Duration(seconds: 60);
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    enabled.value =
        prefs.getBool('always_listening_enabled') ?? false;

    _speech = stt.SpeechToText();
    final available = await _speech!.initialize();
    if (!available) {
      debugPrint('Speech recognition not available');
      enabled.value = false;
    }

    if (enabled.value) {
      start();
    }
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('always_listening_enabled', value);
    enabled.value = value;

    if (value) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (!enabled.value) return;
    _startListeningCycle();
  }

  void stop() {
    _listenTimer?.cancel();
    _pauseTimer?.cancel();
    _stopListening();
    state.value = ListeningState.sleeping;
  }

  void _startListeningCycle() {
    _pauseTimer?.cancel();
    _listenTimer?.cancel();

    if (!enabled.value) return;

    state.value = ListeningState.listening;
    _startListening();

    _listenTimer = Timer(_listenDuration, () {
      _stopListening();
      state.value = ListeningState.paused;

      _pauseTimer = Timer(_pauseDuration, () {
        _startListeningCycle();
      });
    });
  }

  Future<void> _startListening() async {
    if (_isListening || _speech == null) return;
    if (!_speech!.isAvailable) return;

    _isListening = true;
    try {
      await _speech!.listen(
        onResult: (result) {
          if (result.finalResult) {
            final text = result.recognizedWords.toLowerCase().trim();
            if (text.isNotEmpty) {
              _processCommand(text);
            }
          }
        },
        listenFor: _listenDuration,
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: 'pt_BR',
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('AlwaysListening listen error: $e');
      _isListening = false;
    }
  }

  void _stopListening() {
    _isListening = false;
    try {
      _speech?.stop();
    } catch (_) {}
  }

  Future<void> _processCommand(String text) async {
    if (text.isEmpty) return;

    state.value = ListeningState.processing;

    // Check for wake word
    if (!text.startsWith('alex') &&
        !text.startsWith('alê') &&
        !text.startsWith('ale')) {
      state.value = ListeningState.listening;
      return;
    }

    // Remove wake word
    final command = text
        .replaceFirst(RegExp(r'^ale[xê]\s*,?\s*'), '')
        .trim();

    if (command.isEmpty) {
      try {
        await TTSService.instance.falar('Oi! Como posso ajudar?');
      } catch (_) {}
      state.value = ListeningState.listening;
      return;
    }

    await _routeCommand(command);

    state.value = ListeningState.listening;
  }

  Future<void> _routeCommand(String command) async {
    try {
      await TTSService.instance.falar('Claro! Um momento.');

      await AlexAIService.instance.processMessage(command);
    } catch (e) {
      try {
        await TTSService.instance.falar(
          'Desculpe, não consegui processar. Pode repetir?',
        );
      } catch (_) {}
    }
  }

  void dispose() {
    stop();
    _speech?.cancel();
    state.dispose();
    enabled.dispose();
  }
}
