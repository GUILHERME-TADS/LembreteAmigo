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
}
