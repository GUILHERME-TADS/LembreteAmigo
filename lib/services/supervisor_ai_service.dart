import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/smart_alert.dart';
import 'lembrete_service.dart';
import 'smart_alert_service.dart';
import 'effectiveness_service.dart';
import '../utils/reminder_state_helper.dart';
import '../models/lembrete.dart';

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

  String _getUrgencia(Lembrete l) {
    final title = l.titulo.toLowerCase();
    if (title.contains('insulina')) return 'critico';
    if (l.categoria == 'medicacao') return 'aviso';
    return 'normal';
  }

  Map<String, dynamic> _buildElderlyData() {
    final lembretes = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
    final eventos = EffectivenessService.instance.collapseOccurrences(
      LembreteService.instance.eventos,
    );
    final alerts = SmartAlertService.instance.alerts;
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final seteDiasAtras = hoje.subtract(const Duration(days: 7));

    return {
      'data': now.toIso8601String().substring(0, 10),
      'lembretes': lembretes
          .map((l) => {
                'titulo': l.titulo,
                'horario': '${l.horarioHour.toString().padLeft(2, '0')}:${l.horarioMinute.toString().padLeft(2, '0')}',
                'categoria': l.categoria,
                'concluido': l.concluido,
                'recorrencia': l.recorrencia,
                'urgencia': _getUrgencia(l),
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

    };
  }

  SupervisorInsights _buildFallbackSummary() {
    final lembretes = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
    final pendentes = lembretes.where((l) => !l.concluido).toList();
    final total = lembretes.length;
    final concluidos = lembretes.where((l) => l.concluido).toList();
    final alerts = SmartAlertService.instance.alerts;
    final criticos =
        alerts.where((a) => a.severity == SmartAlertSeverity.critical).toList();

    final pct = total > 0 ? (concluidos.length / total * 100).round() : 0;
    final summary = pendentes.isEmpty
        ? 'O idoso concluiu todos os $total lembretes de hoje.'
        : 'O idoso concluiu $pct% dos lembretes '
            '(${concluidos.length} de $total). '
            'Ainda pendentes: ${pendentes.length}.';

    final insights = <String>[];
    if (criticos.isNotEmpty) {
      insights.add(
        'Ha ${criticos.length} alerta(s) critico(s) que requerem atencao.',
      );
    }
    if (pct < 50) {
      insights.add('A adesão aos lembretes está abaixo de 50%.');
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

      final data = Map<String, dynamic>.from(result.data as Map);
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

  Future<Map<String, String>?> generateReportInsights({
    required String idosoName,
    required int adesaoGeral,
    required int totalAtividades,
    required int concluidas,
    required int naoFeitas,
    required int medicacaoPct,
    required int refeicoesPct,
    required int exercicioPct,
    required int hidratacaoPct,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generateReportInsights');
      final result = await callable.call({
        'idosoName': idosoName,
        'adesaoGeral': adesaoGeral,
        'totalAtividades': totalAtividades,
        'concluidas': concluidas,
        'naoFeitas': naoFeitas,
        'medicacaoPct': medicacaoPct,
        'refeicoesPct': refeicoesPct,
        'exercicioPct': exercicioPct,
        'hidratacaoPct': hidratacaoPct,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'resumoFamiliar': data['resumoFamiliar'] as String? ?? '',
        'pontoAtencao': data['pontoAtencao'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('Error calling generateReportInsights: $e');
      return null;
    }
  }
}
