import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class BarcodeResult {
  final String nome;
  final String dosagem;
  final String forma;
  final String cor;
  final String barcode;
  final String erro;

  const BarcodeResult({
    this.nome = '',
    this.dosagem = '',
    this.forma = '',
    this.cor = '',
    this.barcode = '',
    this.erro = '',
  });

  bool get sucesso => erro.isEmpty && nome.isNotEmpty;
}

class BarcodeService {
  BarcodeService._();
  static final BarcodeService _instance = BarcodeService._();
  static BarcodeService get instance => _instance;

  Future<BarcodeResult> lookupBarcode(String barcode) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('lookupBarcode')
          .call({'barcode': barcode});

      final rawData = result.data;
      if (rawData is! Map) {
        return const BarcodeResult(erro: 'Resposta vazia do servidor.');
      }
      final data = Map<String, dynamic>.from(rawData);

      return BarcodeResult(
        nome: (data['nome'] as String? ?? '').trim(),
        dosagem: (data['dosagem'] as String? ?? '').trim(),
        forma: (data['forma'] as String? ?? '').trim(),
        cor: (data['cor'] as String? ?? '').trim(),
        barcode: barcode,
        erro: data['erro'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Erro ao consultar código de barras: $e');
      return BarcodeResult(erro: 'Erro de conexão. Tente novamente.');
    }
  }
}
