import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'secure_cache_service.dart';

class GeminiService {
  // Adicione suas chaves gratuitas do Google AI Studio na lista abaixo para rotação automática
  static const List<String> _apiKeys = [
    'AQ.Ab8RN6K1SS-7VJOA0bmnpx9NKVhQwf0LbHx_yP0MCQusFjExOA',
    'AQ.Ab8RN6Ir16x29eIpnTDgmmA3Sm3CqStO2gN6ggJxA8u1bf1a5g',
    'AQ.Ab8RN6IpFHL8jbFdbspg-kvULciyR3nVFMvpH9xHhuTO_nWZbA',
  ];

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
    final activeKeys = _apiKeys
        .where((key) => key.isNotEmpty && key != 'SUA_CHAVE_AQUI')
        .toList();

    if (activeKeys.isEmpty) {
      return 'Por favor, adicione uma chave da API do Gemini válida no código para usar esta função.';
    }

    final keyNormalizada = _normalizeKey(nomeRemedio);
    final cacheKey = 'gemini_med_explanation_$keyNormalizada';

    // 1. CACHE INTELIGENTE: Verifica se já temos a explicação salva no aparelho
    try {
      final cached = await SecureCacheService.instance.read(cacheKey);
      if (cached != null && cached.trim().isNotEmpty) {
        debugPrint(
          '[GeminiService] Resposta recuperada do CACHE LOCAL para "$nomeRemedio" (0ms)',
        );
        return cached.trim();
      }
    } catch (e) {
      debugPrint('[GeminiService] Erro ao ler cache local: $e');
    }

    // 2. POOL DE CHAVES (MULTI-KEY): Tenta as chaves disponíveis sequencialmente em caso de limite (429)
    for (int i = 0; i < activeKeys.length; i++) {
      final currentKey = activeKeys[i];
      try {
        final model = GenerativeModel(
          model: 'gemini-flash-lite-latest',
          apiKey: currentKey,
          safetySettings: [
            SafetySetting(
              HarmCategory.dangerousContent,
              HarmBlockThreshold.none,
            ),
          ],
        );

        final prompt =
            '''
Você é o Alex, um assistente virtual carinhoso, atencioso e especialista em ajudar idosos.
Sua missão é explicar para um idoso leigo, de forma simples e reconfortante, para que serve o remédio "$nomeRemedio".

Regras Obrigatórias:
1. Responda em no máximo 2 frases curtas, usando palavras simples do cotidiano.
2. Use vírgulas e pontos finais para garantir uma leitura pausada e natural pela síntese de voz (TTS).
3. Evite termos técnicos (ex: em vez de "anti-hipertensivo", diga "ajuda a controlar a pressão do coração").
4. Nunca mencione dosagens, horários específicos nem substitua a orientação do médico.
''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        final responseText = response.text?.trim();

        if (responseText != null && responseText.isNotEmpty) {
          // Grava a explicação no cache para consultas futuras
          await SecureCacheService.instance.write(cacheKey, responseText);
          debugPrint(
            '[GeminiService] Resposta gravada no CACHE LOCAL para "$nomeRemedio"',
          );
          return responseText;
        }
      } catch (e) {
        debugPrint(
          '[GeminiService] Falha na Chave #${i + 1} para "$nomeRemedio": $e',
        );
        if (i == activeKeys.length - 1) {
          // Todas as chaves falharam
          return 'Desculpe, não consegui encontrar informações sobre este remédio no momento.';
        }
        debugPrint(
          '[GeminiService] Alternando para a próxima chave no pool (Chave #${i + 2})...',
        );
      }
    }

    return 'Desculpe, ocorreu um erro ao consultar o assistente inteligente.';
  }
}
