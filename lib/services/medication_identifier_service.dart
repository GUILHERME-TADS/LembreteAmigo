import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MedicationIdentifierResult {
  final String nome;
  final String dosagem;
  final String forma;
  final String cor;
  final String intervaloSugerido;
  final String observacoes;
  final String erro;

  const MedicationIdentifierResult({
    this.nome = '',
    this.dosagem = '',
    this.forma = '',
    this.cor = '',
    this.intervaloSugerido = '',
    this.observacoes = '',
    this.erro = '',
  });

  bool get hasError => erro.isNotEmpty;
  bool get success => nome.isNotEmpty && !hasError;

  factory MedicationIdentifierResult.fromJson(
          Map<String, dynamic> json) =>
      MedicationIdentifierResult(
        nome: json['nome'] as String? ?? '',
        dosagem: json['dosagem'] as String? ?? '',
        forma: json['forma'] as String? ?? '',
        cor: json['cor'] as String? ?? '',
        intervaloSugerido: json['intervaloSugerido'] as String? ?? '',
        observacoes: json['observacoes'] as String? ?? '',
        erro: json['erro'] as String? ?? '',
      );
}

class MedicationIdentifierService {
  MedicationIdentifierService._();
  static final MedicationIdentifierService instance =
      MedicationIdentifierService._();

  Future<MedicationIdentifierResult> identify({
    required String imageBase64,
  }) async {
    try {
      final function = FirebaseFunctions.instance
          .httpsCallable('identifyMedication');
      final result = await function.call({
        'imageBase64': imageBase64,
      });

      final data = result.data as Map<String, dynamic>;
      return MedicationIdentifierResult.fromJson(data);
    } catch (e) {
      return MedicationIdentifierResult(
        erro: 'Erro ao identificar medicamento: $e',
      );
    }
  }
}
