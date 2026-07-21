import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ATENÇÃO: Substitua 'SUA_CHAVE_AQUI' pela sua API Key gratuita gerada no Google AI Studio.
  static const String _apiKey = 'AQ.Ab8RN6K1SS-7VJOA0bmnpx9NKVhQwf0LbHx_yP0MCQusFjExOA'; 
  
  static Future<String> explicarMedicamento(String nomeRemedio) async {
    if (_apiKey == 'SUA_CHAVE_AQUI') {
      return 'Por favor, adicione a chave da API do Gemini no código para usar esta função.';
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-lite-latest',
        apiKey: _apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );

      final prompt = '''
Você é um dicionário de remédios muito amigável, focado em ajudar idosos leigos.
Sua tarefa é explicar, com base em conhecimentos públicos de bulas, para que serve o remédio "$nomeRemedio".
Regras obrigatórias:
1. Responda em no máximo 2 frases curtas.
2. Seja extremamente simples, direto e sem jargões médicos.
3. Não dê conselhos médicos nem dosagens, apenas diga o objetivo geral da medicação.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      return response.text?.trim() ?? 'Desculpe, não consegui encontrar informações sobre este remédio no momento.';
    } catch (e) {
      print('Erro ao consultar o Gemini: $e');
      return 'Desculpe, ocorreu um erro ao consultar o assistente inteligente.';
    }
  }
}
