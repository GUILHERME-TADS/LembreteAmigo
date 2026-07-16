import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AlexMessage {
  final String role;
  final String text;
  final DateTime timestamp;
  AlexMessage({required this.role, required this.text, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class AlexAIResponse {
  final String reply;
  final String actionType;
  final double confidence;
  final Map<String, dynamic>? actionData;

  const AlexAIResponse({
    required this.reply,
    this.actionType = 'general',
    this.confidence = 0,
    this.actionData,
  });

  bool get isEmergency => actionType == 'emergency' && confidence >= 0.8;
  bool get isCreateReminder => actionType == 'create_reminder' && confidence >= 0.5;
  bool get isCompleteReminder => actionType == 'complete_reminder' && confidence >= 0.5;
  bool get isListReminders => actionType == 'list_reminders' && confidence >= 0.5;
  bool get isPostponeReminder => actionType == 'postpone_reminder' && confidence >= 0.5;
}

class AlexVoiceReminderResult {
  final String titulo;
  final int horarioHour;
  final int horarioMinute;
  final String categoria;
  final bool sucesso;
  final String erro;

  const AlexVoiceReminderResult({
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    required this.categoria,
    required this.sucesso,
    this.erro = '',
  });

  factory AlexVoiceReminderResult.fromJson(Map<String, dynamic> json) {
    return AlexVoiceReminderResult(
      titulo: json['titulo'] as String? ?? '',
      horarioHour: (json['horarioHour'] as num?)?.toInt() ?? 0,
      horarioMinute: (json['horarioMinute'] as num?)?.toInt() ?? 0,
      categoria: json['categoria'] as String? ?? 'personalizado',
      sucesso: json['sucesso'] as bool? ?? false,
      erro: json['erro'] as String? ?? '',
    );
  }
}

class AlexAIService {
  AlexAIService._();
  static final AlexAIService _instance = AlexAIService._();
  static AlexAIService get instance => _instance;

  final List<AlexMessage> _history = [];
  static const int _maxHistory = 30;

  List<AlexMessage> get history =>
      List.unmodifiable(_history.take(_maxHistory).toList());

  void addToHistory(String role, String text) {
    _history.add(AlexMessage(role: role, text: text));
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }
  }

  void clearHistory() => _history.clear();

  Future<AlexAIResponse> processMessage(String text) async {
    addToHistory('user', text);
    return _processLocal(text);
  }

  Future<AlexAIResponse> _processLocal(String text) async {
    final normalized = _normalizeSpeech(text);
    if (normalized.isEmpty) {
      return _localResponse(
        'Desculpe, nao entendi. Pode falar de novo mais devagar?',
        'general',
      );
    }

    return _localResponse(
      'Desculpe, ainda nao sei responder a essa pergunta.',
      'general',
    );
  }

  String normalize(String text) => _normalizeSpeech(text);

  String _normalizeSpeech(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  AlexAIResponse _localResponse(
    String reply,
    String actionType, {
    Map<String, dynamic>? data,
    double confidence = 0.7,
  }) {
    final response = AlexAIResponse(
      reply: reply,
      actionType: actionType,
      confidence: confidence,
      actionData: data,
    );
    addToHistory('alex', reply);
    return response;
  }

  Future<AlexVoiceReminderResult?> parseVoiceReminder(String text) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('parseVoiceReminder');
      final result = await callable.call({
        'text': text,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return AlexVoiceReminderResult.fromJson(data);
    } catch (e) {
      debugPrint('Error calling parseVoiceReminder Cloud Function: $e');
      return null;
    }
  }
}
