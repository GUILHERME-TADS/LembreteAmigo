import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/smart_alert.dart';
import 'lembrete_service.dart';
import 'smart_alert_service.dart';
import 'health_service.dart';

class SupervisorInsights {
  final String summary;
  final List<String> insights;
  final List<String> suggestions;
  final List<String> attentionPoints;

  const SupervisorInsights({
    required this.summary,
    this.insights = const [],
    this.suggestions = const [],
    this.attentionPoints = const [],
  });

  bool get hasContent =>
      summary.isNotEmpty ||
      insights.isNotEmpty ||
      suggestions.isNotEmpty ||
      attentionPoints.isNotEmpty;
}

class SupervisorAIService {
  SupervisorAIService._();
  static final SupervisorAIService _instance = SupervisorAIService._();
  static SupervisorAIService get instance => _instance;

  Map<String, dynamic> _buildElderlyData() {
    final lembretes = LembreteService.instance.lembretes;
    final eventos = LembreteService.instance.eventos;
    final alerts = SmartAlertService.instance.alerts;
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final seteDiasAtras = hoje.subtract(const Duration(days: 7));

    return {
      'data': now.toIso8601String().substring(0, 10),
      'lembretes': lembretes
          .where((l) => l.criadoEm.isAfter(seteDiasAtras) || !l.concluido)
          .map((l) => {
                'titulo': l.titulo,
                'horario': '${l.horarioHour.toString().padLeft(2, '0')}:${l.horarioMinute.toString().padLeft(2, '0')}',
                'categoria': l.categoria,
                'concluido': l.concluido,
                'recorrencia': l.recorrencia,
                'urgencia': l.urgencia,
              })
          .toList(),
      'eventos': eventos
          .where((e) => e.registradoEm.isAfter(seteDiasAtras))
          .map((e) => {
                'titulo': e.titulo,
                'categoria': e.categoria,
                'status': e.status.storageValue,
                'registradoEm': e.registradoEm.toIso8601String(),
                'observacao': e.observacao,
              })
          .toList(),
      'alertas': alerts.map((a) => {
            'titulo': a.title,
            'mensagem': a.message,
            'severidade': a.severity.name,
            'criadoEm': a.createdAt.toIso8601String(),
            'minutosAtraso': a.minutesLate,
          }).toList(),
      'batimentos': _buildBpmData(),
    };
  }

  Map<String, dynamic> _buildBpmData() {
    try {
      final healthService = HealthService.instance;
      final bpm = healthService.bpmHistory.isNotEmpty
          ? healthService.bpmHistory.last
          : null;
      final history = healthService.bpmHistory;
      return {
        'ultimoBPM': bpm?.toString() ?? 'N/A',
        'historico': history,
      };
    } catch (e) {
      return {'ultimoBPM': 'N/A', 'historico': []};
    }
  }

  SupervisorInsights _buildFallbackSummary() {
    final lembretes = LembreteService.instance.lembretes;
    final pendentes = lembretes.where((l) => !l.concluido).toList();
    final total = lembretes.length;
    final concluidos = lembretes.where((l) => l.concluido).toList();
    final alerts = SmartAlertService.instance.alerts;
    final criticos =
        alerts.where((a) => a.severity == SmartAlertSeverity.critical).toList();

    final pct = total > 0 ? (concluidos.length / total * 100).round() : 0;
    final summary = pendentes.isEmpty
        ? 'O idoso concluiu todas as ${total} tarefas de hoje.'
        : 'O idoso concluiu $pct% das tarefas '
            '(${concluidos.length} de $total). '
            'Ainda pendentes: ${pendentes.length}.';

    final insights = <String>[];
    if (criticos.isNotEmpty) {
      insights.add(
        'Ha ${criticos.length} alerta(s) critico(s) que requerem atencao.',
      );
    }
    if (pct < 50) {
      insights.add('A adesao as tarefas esta abaixo de 50%.');
    }

    final suggestions = <String>[];
    if (pendentes.isNotEmpty) {
      suggestions.add(
        'Enviar mensagem para o idoso perguntando se precisa de ajuda.',
      );
    }

    return SupervisorInsights(
      summary: summary,
      insights: insights,
      suggestions: suggestions,
      attentionPoints: criticos.map((a) => a.message).toList(),
    );
  }

  Future<SupervisorInsights> getDailySummary() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('supervisorChat');
      final result = await callable.call({
        'elderlyData': _buildElderlyData(),
      });

      final data = result.data as Map<String, dynamic>;
      return SupervisorInsights(
        summary: data['summary'] as String? ?? '',
        insights: _toStringList(data['insights']),
        suggestions: _toStringList(data['suggestions']),
        attentionPoints: _toStringList(data['attentionPoints']),
      );
    } catch (e) {
      debugPrint('supervisorChat error, using fallback: $e');
      return _buildFallbackSummary();
    }
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
