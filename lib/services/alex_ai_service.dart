import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/lembrete.dart';
import 'lembrete_service.dart';

class AlexMessage {
  final String role;
  final String text;
  final DateTime timestamp;
  AlexMessage({required this.role, required this.text, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class AlexAIResponse {
  final String reply;
  final String emotion;
  final String actionType;
  final double confidence;
  final Map<String, dynamic>? actionData;

  const AlexAIResponse({
    required this.reply,
    this.emotion = 'informativo',
    this.actionType = 'general',
    this.confidence = 0,
    this.actionData,
  });

  bool get isEmergency => actionType == 'emergency' && confidence >= 0.8;
  bool get isCreateReminder => actionType == 'create_reminder' && confidence >= 0.5;
  bool get isCompleteReminder => actionType == 'complete_reminder' && confidence >= 0.5;
  bool get isListReminders => actionType == 'list_reminders' && confidence >= 0.5;
  bool get isPostponeReminder => actionType == 'postpone_reminder' && confidence >= 0.5;
  bool get isSentimentLog => actionType == 'sentiment_log' && confidence >= 0.5;

  String get effectiveEmotion {
    if (isEmergency) return 'emergencia';
    return emotion;
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

  List<Map<String, dynamic>> _buildHistoryForApi() {
    return _history
        .skip(1)
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
  }

  List<Map<String, dynamic>> _buildReminderContext() {
    final lembretes = LembreteService.instance.lembretes;
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);

    return lembretes
        .where((l) =>
            l.criadoEm.isAfter(hoje.subtract(const Duration(days: 1))) ||
            !l.concluido)
        .map((l) => {
              'id': l.id,
              'titulo': l.titulo,
              'horario': '${l.horarioHour.toString().padLeft(2, '0')}:${l.horarioMinute.toString().padLeft(2, '0')}',
              'categoria': l.categoria,
              'concluido': l.concluido,
              'recorrencia': l.recorrencia,
              'urgencia': l.urgencia,
            })
        .toList();
  }

  Future<AlexAIResponse> processMessage(String text) async {
    addToHistory('user', text);

    final emBreve = _detectEmergencyLocal(text);
    if (emBreve != null) return emBreve;

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('alexChat');
      final result = await callable.call({
        'message': text,
        'conversationHistory': _buildHistoryForApi(),
        'reminderContext': _buildReminderContext(),
      });

      final data = result.data as Map<String, dynamic>;
      final action = data['action'] as Map<String, dynamic>?;

      final response = AlexAIResponse(
        reply: data['reply'] as String? ?? '',
        emotion: data['emotion'] as String? ?? 'informativo',
        actionType: action?['type'] as String? ?? 'general',
        confidence: (action?['confidence'] as num?)?.toDouble() ?? 0,
      );

      addToHistory('alex', response.reply);
      return response;
    } catch (e) {
      debugPrint('Cloud Function error, falling back to local: $e');
      return _processLocal(text);
    }
  }

  Future<AlexAIResponse> _processLocal(String text) async {
    final normalized = _normalizeSpeech(text);
    if (normalized.isEmpty) {
      return _localResponse(
        'Desculpe, nao entendi. Pode falar de novo mais devagar?',
        'general',
      );
    }

    final listMatch = _processListLocal(normalized);
    if (listMatch != null) return listMatch;

    final completeMatch = await _processCompleteLocal(normalized);
    if (completeMatch != null) return completeMatch;

    final sentimentMatch = _processSentimentLocal(normalized);
    if (sentimentMatch != null) return sentimentMatch;

    return _localResponse(
      'Nao entendi ainda. Tente dizer: quais sao minhas tarefas, ja fiz, tomei o remedio, ou preciso de ajuda.',
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

  bool _hasAny(String text, List<String> words) =>
      words.any(text.contains);

  AlexAIResponse? _detectEmergencyLocal(String text) {
    final lower = text.toLowerCase();
    if (_hasAny(lower, const [
      'dor', 'ajuda', 'socorro', 'emergencia', 'passando mal',
      'machuquei', 'cai', 'cair', 'queda', 'chama alguem',
      'chamar alguem', 'preciso de alguem',
    ])) {
      return AlexAIResponse(
        reply: 'Estou pedindo socorro e avisando quem cuida de voce agora mesmo.',
        emotion: 'emergencia',
        actionType: 'emergency',
        confidence: 0.95,
      );
    }
    return null;
  }

  AlexAIResponse? _processListLocal(String normalized) {
    if (_hasAny(normalized, const [
      'quais', 'lista', 'ver', 'lembrete', 'remedio', 'tarefas',
      'atividade', 'hoje', 'o que tenho', 'minha rotina',
    ])) {
      final pendentes =
          LembreteService.instance.lembretes.where((l) => !l.concluido).toList();

      String reply;
      if (pendentes.isEmpty) {
        reply = 'Muito bem. Voce ja terminou todas as suas tarefas de hoje.';
      } else {
        reply = 'Voce tem ${pendentes.length} tarefa${pendentes.length > 1 ? 's' : ''} para fazer hoje. ';
        for (int i = 0; i < pendentes.length; i++) {
          final l = pendentes[i];
          final spokenTime =
              '${l.horarioHour.toString().padLeft(2, '0')} e ${l.horarioMinute.toString().padLeft(2, '0')}';
          reply += '${i + 1}. ${l.titulo}, as $spokenTime. ';
        }
      }

      return _localResponse(reply, 'list_reminders', data: {
        'count': pendentes.length,
      });
    }
    return null;
  }

  Future<AlexAIResponse?> _processCompleteLocal(String normalized) async {
    if (!_hasAny(normalized, const [
      'tomei', 'ja tomei', 'conclui', 'fiz', 'ja fiz', 'bebi',
      'comi', 'terminei', 'marcar', 'finalizar', 'pronto', 'feito', 'ok',
    ])) {
      return null;
    }

    final pending =
        LembreteService.instance.lembretes.where((l) => !l.concluido).toList();
    Lembrete? match;

    final commandWords = RegExp(
      r'\b(tomei|ja|conclui|fiz|bebi|comi|terminei|marcar|finalizar|pronto|feito|ok|o|a|um|uma|remedio|atividade|tarefa)\b',
    );
    final meaningfulText = normalized
        .replaceAll(commandWords, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final l in pending) {
      final titleClean = _normalizeSpeech(l.titulo);
      if (titleClean.isEmpty) continue;
      if (normalized.contains(titleClean) ||
          (meaningfulText.length >= 3 && titleClean.contains(meaningfulText))) {
        match = l;
        break;
      }
    }

    if (match != null) {
      return _localResponse(
        'Tudo certo. Marquei que voce terminou: ${match.titulo}.',
        'complete_reminder',
        data: {'reminderTitle': match.titulo, 'lembreteId': match.id},
      );
    }

    final meds =
        pending.where((l) => l.categoria == 'medicacao').toList();
    final canCompleteOnlyTask =
        pending.length == 1 &&
        _hasAny(normalized, const ['fiz', 'ja fiz', 'pronto', 'feito', 'ok']);
    final canCompleteOnlyMedicine =
        meds.length == 1 &&
        _hasAny(normalized, const ['tomei', 'ja tomei', 'remedio']);

    if (canCompleteOnlyTask || canCompleteOnlyMedicine) {
      final item = canCompleteOnlyMedicine ? meds.first : pending.first;
      return _localResponse(
        'Tudo certo. Marquei que voce terminou: ${item.titulo}.',
        'complete_reminder',
        data: {'reminderTitle': item.titulo, 'lembreteId': item.id},
      );
    }

    return null;
  }

  AlexAIResponse? _processSentimentLocal(String normalized) {
    if (_hasAny(normalized, const ['triste', 'ansioso', 'ansiosa', 'preocupado',
        'preocupada', 'sozinho', 'sozinha', 'mal', 'cansado', 'cansada'])) {
      return _localResponse(
        'Sinto muito que voce esta se sentindo assim. Lembre-se que voce nao esta sozinho. '
        'Que tal dar uma olhada nas suas tarefas para se distrair?',
        'sentiment_log',
      );
    }
    if (_hasAny(normalized, const ['feliz', 'alegre', 'bem', 'otimo', 'obrigado',
        'obrigada', 'consegui'])) {
      return _localResponse(
        'Que maravilha! Fico muito feliz em saber disso. Continue assim!',
        'sentiment_log',
      );
    }
    return null;
  }

  String _emotionForAction(String actionType, {Map<String, dynamic>? data}) {
    switch (actionType) {
      case 'emergency':
        return 'emergencia';
      case 'complete_reminder':
        return 'alegre';
      case 'sentiment_log':
        final sentiment = data?['sentiment'] as String?;
        if (sentiment == 'triste' || sentiment == 'ansioso') return 'calma';
        if (sentiment == 'feliz') return 'alegre';
        return 'calma';
      default:
        return 'informativo';
    }
  }

  AlexAIResponse _localResponse(
    String reply,
    String actionType, {
    Map<String, dynamic>? data,
    double confidence = 0.7,
  }) {
    final response = AlexAIResponse(
      reply: reply,
      emotion: _emotionForAction(actionType, data: data),
      actionType: actionType,
      confidence: confidence,
      actionData: data,
    );
    addToHistory('alex', reply);
    return response;
  }
}
