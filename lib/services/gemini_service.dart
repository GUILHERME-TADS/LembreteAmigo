import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'secure_cache_service.dart';

class GeminiService {
  static String _normalizeKey(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  static Future<String> explicarMedicamento(String nomeRemedio) async {
    final nome = nomeRemedio.trim();
    if (nome.isEmpty) {
      return 'Não encontrei o nome do remédio para explicar.';
    }

    final cacheKey = 'gemini_med_explanation_${_normalizeKey(nome)}';

    try {
      final cached = await SecureCacheService.instance.read(cacheKey);
      if (cached != null && cached.trim().isNotEmpty) {
        debugPrint('[GeminiService] Resposta recuperada do cache para $nome.');
        return cached.trim();
      }
    } catch (error) {
      debugPrint('[GeminiService] Erro ao ler cache local: $error');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'queryMedicationFAQ',
      );
      final result = await callable.call(<String, dynamic>{
        'medicationName': nome,
        'question':
            'Para que serve este remédio? Explique para uma pessoa idosa, '
            'em no máximo duas frases curtas e com palavras simples.',
      });

      final rawData = result.data;
      if (rawData is! Map) {
        throw const FormatException('Resposta inválida do serviço de IA.');
      }

      final data = Map<String, dynamic>.from(rawData);
      final answer = (data['answer'] as String? ?? '').trim();
      if (answer.isEmpty) {
        throw const FormatException('Resposta vazia do serviço de IA.');
      }

      try {
        await SecureCacheService.instance.write(cacheKey, answer);
      } catch (error) {
        debugPrint('[GeminiService] Erro ao gravar cache local: $error');
      }
      return answer;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[GeminiService] Função queryMedicationFAQ falhou '
        '(${error.code}): ${error.message ?? 'sem detalhes'}',
      );
    } catch (error) {
      debugPrint('[GeminiService] Erro ao consultar explicação: $error');
    }

    return 'Desculpe, não consegui encontrar informações sobre este remédio '
        'no momento. Peça ajuda ao seu médico ou farmacêutico.';
  }
}
