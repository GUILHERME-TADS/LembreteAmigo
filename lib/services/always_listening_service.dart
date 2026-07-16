import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
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
  Timer? _relaunchTimer;
  Timer? _retryTimer;
  Timer? _wakeWordOnlyTimer;
  bool _initialized = false;
  bool _isListening = false;
  bool _commandTriggeredForSession = false;
  bool _awaitingCommand = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    enabled.value =
        prefs.getBool('always_listening_enabled') ?? false;

    if (enabled.value) {
      start();
    }
  }

  Future<bool> _initSpeech() async {
    _speech ??= stt.SpeechToText();
    if (_speech!.isAvailable) return true;

    try {
      final available = await _speech!.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!available) {
        _speech = null;
      }
      return available;
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speech = null;
      return false;
    }
  }

  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final recorder = AudioRecorder();
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        await prefs.setBool('always_listening_enabled', false);
        enabled.value = false;
        state.value = ListeningState.sleeping;
        return false;
      }

      final speechAvailable = await _initSpeech();
      if (!speechAvailable) {
        await prefs.setBool('always_listening_enabled', false);
        enabled.value = false;
        state.value = ListeningState.sleeping;
        return false;
      }
    }

    await prefs.setBool('always_listening_enabled', value);
    enabled.value = value;

    if (value) {
      start();
    } else {
      stop();
    }
    return true;
  }

  void start() {
    if (!enabled.value) return;
    state.value = ListeningState.listening;
    _startListening();
  }

  void stop() {
    _relaunchTimer?.cancel();
    _retryTimer?.cancel();
    _stopListening();
    _speech = null;
    state.value = ListeningState.sleeping;
  }

  void pauseTemporarily() {
    if (!enabled.value) return;
    _relaunchTimer?.cancel();
    _retryTimer?.cancel();
    _stopListening();
    state.value = ListeningState.paused;
  }

  void resumeIfEnabled() {
    if (!enabled.value) return;
    if (state.value == ListeningState.processing) return;
    state.value = ListeningState.listening;
    _startListening();
  }

  void _handleStatus(String status) {
    debugPrint('AlwaysListening status: $status');
    if (status == 'listening') {
      _isListening = true;
      state.value = ListeningState.listening;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
      _checkRelaunch();
    }
  }

  void _handleError(dynamic error) {
    debugPrint('AlwaysListening error: $error');
    _isListening = false;
    _checkRelaunch();
  }

  void _checkRelaunch() {
    if (!enabled.value ||
        state.value == ListeningState.processing ||
        state.value == ListeningState.sleeping) {
      return;
    }
    _relaunchTimer?.cancel();
    _relaunchTimer = Timer(const Duration(milliseconds: 1000), () {
      if (enabled.value &&
          state.value != ListeningState.processing &&
          state.value != ListeningState.sleeping) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    final available = await _initSpeech();
    if (!available) {
      debugPrint('AlwaysListening: Speech recognition not available, retrying soon...');
      state.value = ListeningState.paused;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), () {
        if (enabled.value &&
            state.value != ListeningState.processing &&
            state.value != ListeningState.sleeping) {
          _startListening();
        }
      });
      return;
    }

    _isListening = true;
    _commandTriggeredForSession = false;
    try {
      await _speech!.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase().trim();

          if (_awaitingCommand) {
            _wakeWordOnlyTimer?.cancel();
            if (_commandTriggeredForSession) return;

            if (result.finalResult && text.isEmpty) {
              _commandTriggeredForSession = true;
              _awaitingCommand = false;
              _processEmptyCommand();
              return;
            }

            if (text.isNotEmpty) {
              if (result.finalResult || text.length >= 3) {
                _commandTriggeredForSession = true;
                _processCommand(text);
              }
            }
            return;
          }

          final wakeMatch =
              RegExp(r'^(alex|alê|ale)(?:\s*,?\s*|$)').firstMatch(text);

          if (wakeMatch == null) {
            _wakeWordOnlyTimer?.cancel();
            return;
          }

          final commandText = text.substring(wakeMatch.end).trim();

          if (_commandTriggeredForSession) {
            _wakeWordOnlyTimer?.cancel();
            return;
          }

          if (result.finalResult) {
            _wakeWordOnlyTimer?.cancel();
            _commandTriggeredForSession = true;
            _processCommand(text);
            return;
          }

          if (commandText.isEmpty) {
            _wakeWordOnlyTimer?.cancel();
            _wakeWordOnlyTimer = Timer(const Duration(milliseconds: 1500), () {
              if (!_commandTriggeredForSession && enabled.value) {
                _commandTriggeredForSession = true;
                _processCommand(text);
              }
            });
          } else {
            _wakeWordOnlyTimer?.cancel();
            if (commandText.length >= 3) {
              _commandTriggeredForSession = true;
              _processCommand(text);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
          localeId: 'pt_BR',
        ),
      );
    } catch (e) {
      debugPrint('AlwaysListening listen error: $e');
      _isListening = false;
      _checkRelaunch();
    }
  }

  void _stopListening() {
    _isListening = false;
    _wakeWordOnlyTimer?.cancel();
    try {
      _speech?.stop();
    } catch (_) {}
  }

  Future<void> _processEmptyCommand() async {
    state.value = ListeningState.processing;
    _stopListening();
    await _routeCommand('');
    state.value = ListeningState.listening;
    _startListening();
  }

  Future<void> _processCommand(String text) async {
    if (text.isEmpty) return;

    state.value = ListeningState.processing;
    _stopListening();

    final wasAwaiting = _awaitingCommand;
    _awaitingCommand = false;

    final wakeMatch =
        RegExp(r'^(alex|alê|ale)(?:\s*,?\s*|$)').firstMatch(text);
    if (wakeMatch == null) {
      if (!wasAwaiting) {
        state.value = ListeningState.listening;
        _startListening();
        return;
      }
    }

    final command = wakeMatch == null ? text.trim() : text.substring(wakeMatch.end).trim();

    if (command.isEmpty) {
      try {
        _awaitingCommand = true;
        await TTSService.instance.falar('Oi! Como posso ajudar?');
      } catch (_) {}
      state.value = ListeningState.listening;
      _startListening();
      return;
    }

    await _routeCommand(command);

    state.value = ListeningState.listening;
    _startListening();
  }

  Future<void> _routeCommand(String command) async {
    try {
      final response = await AlexAIService.instance.processMessage(command);
      if (response.reply.isNotEmpty) {
        await TTSService.instance.falar(response.reply);
      } else {
        await TTSService.instance.falar(
          'Desculpe, não encontrei uma resposta para isso agora.',
        );
      }
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
