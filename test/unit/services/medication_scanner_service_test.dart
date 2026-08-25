import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/medication_scan_result.dart';
import 'package:lembretes_app/services/medication_scanner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicationScannerService', () {
    test('identifica Losartana e dosagem correta pelo texto', () {
      final result = MedicationScannerService.instance.parseFromText('losartana_potassica_50mg.jpg');

      expect(result.nome, 'Losartana');
      expect(result.dosagem, '50mg');
      expect(result.explicacaoSimples, contains('pressão arterial'));
      expect(result.tituloCompleto, 'Losartana 50mg');
    });

    test('identifica Rivotril em gotas', () {
      final result = MedicationScannerService.instance.parseFromText('caixa_rivotril_gotas_2mg.png');

      expect(result.nome, 'Rivotril');
      expect(result.dosagem, '2mg');
      expect(result.explicacaoSimples, contains('ansiedade'));
    });

    test('identifica Omeprazol em cápsula', () {
      final result = MedicationScannerService.instance.parseFromText('omeprazol_20mg_capsula.jpg');

      expect(result.nome, 'Omeprazol');
      expect(result.dosagem, '20mg');
      expect(result.explicacaoSimples, contains('estômago'));
    });

    test('retorna valores padrão quando o nome não está na base', () {
      final result = MedicationScannerService.instance.parseFromText('medicamento_desconhecido_10mg.jpg');

      expect(result.dosagem, '10mg');
      expect(result.confianca, 0.70);
    });

    test('MedicationScanResult toMap e fromMap serializam com integridade', () {
      final original = MedicationScanResult(
        nome: 'Dipirona',
        dosagem: '500mg',
        explicacaoSimples: 'Alivia dores e febre.',
        confianca: 0.99,
      );

      final map = original.toMap();
      final from = MedicationScanResult.fromMap(map);

      expect(from.nome, original.nome);
      expect(from.dosagem, original.dosagem);
      expect(from.tituloCompleto, 'Dipirona 500mg');
    });
  });
}
