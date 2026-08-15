import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService - validação local', () {
    test('não consulta o servidor quando o nome está vazio', () async {
      final result = await GeminiService.explicarMedicamento('   ');

      expect(result, 'Não encontrei o nome do remédio para explicar.');
    });
  });
}
