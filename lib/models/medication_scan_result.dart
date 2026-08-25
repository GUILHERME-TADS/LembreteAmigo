/// Modelo de dados que encapsula as informações extraídas de uma caixa de remédio ou bula via IA.
class MedicationScanResult {
  final String nome;
  final String? dosagem;
  final String? instrucoes;
  final String? explicacaoSimples;
  final double confianca;
  final String? fotoPath;

  const MedicationScanResult({
    required this.nome,
    this.dosagem,
    this.instrucoes,
    this.explicacaoSimples,
    this.confianca = 1.0,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'dosagem': dosagem,
      'instrucoes': instrucoes,
      'explicacaoSimples': explicacaoSimples,
      'confianca': confianca,
      'fotoPath': fotoPath,
    };
  }

  factory MedicationScanResult.fromMap(Map<String, dynamic> map) {
    return MedicationScanResult(
      nome: map['nome'] as String? ?? map['medicationName'] as String? ?? 'Medicamento',
      dosagem: map['dosagem'] as String? ?? map['dose'] as String?,
      instrucoes: map['instrucoes'] as String? ?? map['instructions'] as String?,
      explicacaoSimples: map['explicacaoSimples'] as String? ?? map['explanation'] as String?,
      confianca: (map['confianca'] as num?)?.toDouble() ?? 1.0,
      fotoPath: map['fotoPath'] as String?,
    );
  }

  /// Retorna o título formatado completo (ex: "Losartana 50mg")
  String get tituloCompleto {
    if (dosagem != null && dosagem!.isNotEmpty && !nome.toLowerCase().contains(dosagem!.toLowerCase())) {
      return '$nome $dosagem';
    }
    return nome;
  }
}
