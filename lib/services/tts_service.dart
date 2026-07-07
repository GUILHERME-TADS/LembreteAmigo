import 'dart:async';
import 'package:flutter/foundation.dart';
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
    await _selectVoiceByGender(_voiceProfile.gender);
    await _tts.setSpeechRate(_voiceProfile.speechRate);
    await _tts.setPitch(_voiceProfile.pitch);
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
    await _selectVoiceByGender(profile.gender);
    await _tts.setSpeechRate(profile.speechRate);
    await _tts.setPitch(profile.pitch);
    await _tts.setVolume(1.0);
  }

  Future<void> updateProfile(AlexVoiceProfile profile) async {
    _voiceProfile = profile;
    await profile.save();
    await initFromProfile(profile);
  }

  Future<void> _selectVoiceByGender(AlexVoiceGender gender) async {
    try {
      final voices = await _tts.getVoices;
      if (voices == null || voices is! List || voices.isEmpty) return;

      final langFilter = voices
          .where((v) {
            if (v is! Map) return false;
            final name = (v['name'] as String? ?? '').toLowerCase();
            final locale = (v['locale'] as String? ?? '').toLowerCase();
            return name.contains('pt') || name.contains('port') ||
                locale.contains('pt') || locale.contains('bra');
          })
          .toList();

      if (langFilter.isEmpty) return;

      final genderFilter = langFilter.where((v) {
        if (v is! Map) return false;
        final name = (v['name'] as String? ?? '').toLowerCase();
        if (gender == AlexVoiceGender.female) {
          return name.contains('female') || name.contains('feminina');
        } else {
          return name.contains('male') || name.contains('masculina');
        }
      }).toList();

      final selected = genderFilter.isNotEmpty
          ? genderFilter.first
          : langFilter.first;

      if (selected is Map && selected['name'] != null) {
        await _tts.setVoice({
          'name': selected['name'] as String,
          'language': 'pt-BR',
        });
      }
    } catch (e) {
      debugPrint('Erro ao selecionar voz TTS: $e');
    }
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
    await _tts.speak(texto);
    return _completer!.future;
  }

  Future<void> falarComEmocao(
    String texto,
    String emotion, {
    Object? caller,
  }) async {
    double targetRate;
    double targetPitch;
    double targetVolume;

    switch (emotion) {
      case 'calma':
        targetRate = _voiceProfile.speechRate * 0.85;
        targetPitch = _voiceProfile.pitch * 0.9;
        targetVolume = 0.85;
      case 'alegre':
        targetRate = _voiceProfile.speechRate * 1.1;
        targetPitch = _voiceProfile.pitch * 1.3;
        targetVolume = 0.95;
      case 'informativo':
        targetRate = _voiceProfile.speechRate;
        targetPitch = _voiceProfile.pitch;
        targetVolume = 0.9;
      case 'urgente':
        targetRate = _voiceProfile.speechRate * 1.3;
        targetPitch = _voiceProfile.pitch * 0.85;
        targetVolume = 1.0;
      case 'emergencia':
        targetRate = _voiceProfile.speechRate * 1.4;
        targetPitch = _voiceProfile.pitch * 0.8;
        targetVolume = 1.0;
      default:
        targetRate = _voiceProfile.speechRate;
        targetPitch = _voiceProfile.pitch;
        targetVolume = 0.9;
    }

    _cancelSpeech = true;
    await _tts.stop();
    _cancelSpeech = false;

    await _tts.setSpeechRate(targetRate.clamp(0.1, 1.0));
    await _tts.setPitch(targetPitch.clamp(0.5, 2.0));
    await _tts.setVolume(targetVolume.clamp(0.5, 1.0));

    _activeCaller = caller;
    _activeText = texto;
    _activeSessionToken = Object();
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
    _activeSessionToken = null;
    await _tts.stop();
    _resetCompleter();

    await _tts.setSpeechRate(_voiceProfile.speechRate);
    await _tts.setPitch(_voiceProfile.pitch);
  }

  Future<void> falarLista(List<String> textos, {Object? caller}) async {
    _cancelSpeech = true;
    await _tts.stop();
    _cancelSpeech = false;
    _activeCaller = caller;
    final sessionToken = Object();
    _activeSessionToken = sessionToken;
    for (var i = 0; i < textos.length; i++) {
      if (_cancelSpeech || _activeCaller != caller || _activeSessionToken != sessionToken) break;
      _completer = Completer<void>();
      speakingNotifier.value = true;
      await _tts.speak(textos[i]);
      try {
        await _completer!.future;
      } catch (_) {}
      if (_cancelSpeech || _activeCaller != caller || _activeSessionToken != sessionToken) break;
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
    _activeCaller = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
  }
}
