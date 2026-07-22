import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService - Cache & Multi-Key Pool', () {
    test('retorna mensagem de aviso se nao houver chaves configuradas', () async {
      final res = await GeminiService.explicarMedicamento('Dipirona');
      expect(res, isNotNull);
      expect(res.isNotEmpty, true);
    });
  });
}
