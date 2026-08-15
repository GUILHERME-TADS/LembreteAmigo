import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'alex_voice_profile.dart';

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
  Object? _activeSessionToken;
  AlexVoiceProfile _voiceProfile = const AlexVoiceProfile();
  bool _voiceInitialized = false;

  bool get isSpeaking => speakingNotifier.value;
  Object? get activeCaller => _activeCaller;
  String? get activeText => _activeText;
  AlexVoiceProfile get voiceProfile => _voiceProfile;

  Future<void> init() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      _resetCompleter();
    });
    _tts.setErrorHandler((message) {
      debugPrint('Erro na síntese de voz TTS: $message');
      _resetCompleter();
    });
    _voiceProfile = await AlexVoiceProfile.load();
    await _applyProfileSettings();
    _voiceInitialized = true;
  }

  Future<void> initFromProfile(AlexVoiceProfile profile) async {
    _voiceProfile = profile;
    if (!_voiceInitialized) {
      await _tts.setLanguage('pt-BR');
      _tts.setCompletionHandler(() => _resetCompleter());
      _tts.setErrorHandler((message) {
        debugPrint('Erro na síntese de voz TTS: $message');
        _resetCompleter();
      });
      _voiceInitialized = true;
    }
    await _applyProfileSettings();
  }

  Future<void> updateProfile(AlexVoiceProfile profile) async {
    _voiceProfile = profile;
    await profile.save();
    await initFromProfile(profile);
  }

  Future<void> _applyProfileSettings() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(_voiceProfile.speechRate);
    await _tts.setPitch(_voiceProfile.pitch);
    await _tts.setVolume(1.0);
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
    _activeSessionToken = Object();
    _completer = Completer<void>();
    speakingNotifier.value = true;
    await _applyProfileSettings();
    await _tts.speak(texto);
    return _completer!.future;
  }

  Future<void> parar({Object? caller}) async {
    if (caller != null && _activeCaller != caller) {
      return;
    }
    _cancelSpeech = true;
    _activeSessionToken = null;
    _activeCaller = null;
    await _tts.stop();
    _resetCompleter();

    await _applyProfileSettings();
  }

  Future<void> falarLista(List<String> textos, {Object? caller}) async {
    _cancelSpeech = true;
    await _tts.stop();
    _cancelSpeech = false;
    _activeCaller = caller;
    final sessionToken = Object();
    _activeSessionToken = sessionToken;
    await _applyProfileSettings();
    for (var i = 0; i < textos.length; i++) {
      if (_cancelSpeech ||
          _activeCaller != caller ||
          _activeSessionToken != sessionToken) {
        break;
      }
      _completer = Completer<void>();
      speakingNotifier.value = true;
      await _tts.speak(textos[i]);
      try {
        await _completer!.future;
      } catch (_) {}
      if (_cancelSpeech ||
          _activeCaller != caller ||
          _activeSessionToken != sessionToken) {
        break;
      }
      if (i < textos.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_activeCaller == caller && _activeSessionToken == sessionToken) {
      speakingNotifier.value = false;
    }
  }

  void _resetCompleter() {
    speakingNotifier.value = false;
    _activeText = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
  }

  /// Gera um arquivo de áudio local com a voz da assistente e retorna o caminho absoluto.
  Future<String?> gerarAudioDoTexto(String texto, String idLembrete) async {
    try {
      await _applyProfileSettings();
      final dir = await getApplicationDocumentsDirectory();
      final extension = Platform.isIOS ? 'caf' : 'wav';
      final filePath = '${dir.path}/tts_lembrete_$idLembrete.$extension';

      final result = await _tts.synthesizeToFile(texto, filePath);
      if (result == 1) {
        return filePath;
      } else {
        debugPrint(
          'Erro ao sintetizar arquivo de áudio para o lembrete $idLembrete',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Erro inesperado em gerarAudioDoTexto: $e');
      return null;
    }
  }
}
