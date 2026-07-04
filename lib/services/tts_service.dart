import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  TTSService._();
  static final TTSService _instance = TTSService._();
  static TTSService get instance => _instance;

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> speakingNotifier = ValueNotifier(false);
  Completer<void>? _completer;
  bool _cancelSpeech = false;
  Object? _activeCaller;
  String? _activeText;

  bool get isSpeaking => speakingNotifier.value;
  Object? get activeCaller => _activeCaller;
  String? get activeText => _activeText;

  Future<void> init() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      speakingNotifier.value = false;
      _activeText = null;
      _activeCaller = null;
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
    });
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> falar(String texto, {Object? caller}) async {
    _cancelSpeech = true;
    await _tts.stop();
    _cancelSpeech = false;
    _activeCaller = caller;
    _activeText = texto;
    _completer = Completer<void>();
    speakingNotifier.value = true;
    await _tts.speak(texto);
    return _completer!.future;
  }

  Future<void> parar({Object? caller}) async {
    if (caller != null && _activeCaller != caller) {
      return;
    }
    _cancelSpeech = true;
    await _tts.stop();
    speakingNotifier.value = false;
    _activeText = null;
    _activeCaller = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
  }

  Future<void> falarLista(List<String> textos, {Object? caller}) async {
    _cancelSpeech = true;
    await _tts.stop();
    _cancelSpeech = false;
    _activeCaller = caller;
    for (var i = 0; i < textos.length; i++) {
      if (_cancelSpeech || _activeCaller != caller) break;
      _completer = Completer<void>();
      speakingNotifier.value = true;
      await _tts.speak(textos[i]);
      try {
        await _completer!.future;
      } catch (_) {}
      if (_cancelSpeech || _activeCaller != caller) break;
      if (i < textos.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_activeCaller == caller) {
      speakingNotifier.value = false;
    }
  }
}
