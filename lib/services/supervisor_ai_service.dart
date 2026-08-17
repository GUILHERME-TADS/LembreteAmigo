import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'session_role_service.dart';

class SupervisorAIService {
  SupervisorAIService._();
  static final SupervisorAIService _instance = SupervisorAIService._();
  static SupervisorAIService get instance => _instance;

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
      final elderlyId = await SessionRoleService.getVerifiedActiveIdosoId();
      if (elderlyId == null) {
        throw StateError('Vinculo com o idoso nao confirmado.');
      }
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generateReportInsights');
      final result = await callable.call({
        'elderlyId': elderlyId,
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

  List<String> detectAnomalies({
    required List<dynamic> eventos,
    required List<dynamic> lembretes,
  }) {
    final insights = <String>[];
    final now = DateTime.now();
    final recent = eventos.where((e) {
      final reg = e.registradoEm as DateTime?;
      return reg != null && now.difference(reg).inDays <= 7;
    }).toList();

    // 1. Verificar adiamentos frequentes
    final adiados = recent.where((e) => e.status.toString().contains('adiado')).length;
    if (adiados >= 3) {
      insights.add('⚠️ Padrão detectado: $adiados adiamentos nos últimos 7 dias. Vale verificar se os horários estão convenientes.');
    }

    // 2. Verificar lembretes perdidos
    final perdidos = recent.where((e) => e.status.toString().contains('perdido')).length;
    if (perdidos >= 2) {
      insights.add('🚨 Alerta: $perdidos lembretes não foram concluídos recentemente.');
    }

    // 3. Boa adesão
    final concluidos = recent.where((e) => e.status.toString().contains('concluido') || e.status.toString().contains('sucesso')).length;
    if (recent.isNotEmpty && (concluidos / recent.length) >= 0.85) {
      insights.add('🌟 Excelente adesão! Mais de 85% das atividades concluídas no prazo esta semana.');
    }

    return insights;
  }
}

