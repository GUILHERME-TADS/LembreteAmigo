import 'package:flutter/foundation.dart';
import '../models/lembrete.dart';
import 'tts_service.dart';

class VoiceNotificationService {
  VoiceNotificationService._();
  static final VoiceNotificationService _instance = VoiceNotificationService._();
  static VoiceNotificationService get instance => _instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> speakReminder(Lembrete lembrete) async {
    final prefix = _prefixForUrgency('critico');
    final categoryName = _categoryName(lembrete.categoria);
    final text = '$prefix Alex diz: está na hora de $categoryName! ${lembrete.titulo}.';
    await TTSService.instance.falar(text);
  }

  Future<void> speakTitle(String lembreteTitulo, {String? categoria, String? urgencia}) async {
    final prefix = _prefixForUrgency('critico');
    final categoryInfo = categoria != null ? ' ${_categoryName(categoria)}' : '';
    final text = '$prefix Alex diz: está na hora$categoryInfo! $lembreteTitulo.';
    await TTSService.instance.falar(text);
  }

  String prefixForUrgency(String urgencia) {
    switch (urgencia) {
      case 'critico':
        return 'Alerta urgente!';
      case 'importante':
        return 'Aviso importante!';
      default:
        return 'Atenção!';
    }
  }

  String categoryName(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return 'do seu remédio';
      case 'refeicoes':
        return 'de comer';
      case 'exercicio':
        return 'do seu exercício';
      case 'hidratacao':
        return 'de beber água';
      default:
        return 'do seu lembrete';
    }
  }

  String _prefixForUrgency(String urgencia) => prefixForUrgency(urgencia);
  String _categoryName(String categoria) => categoryName(categoria);
}
