import 'package:cloud_functions/cloud_functions.dart';

class PrescriptionReminderItem {
  final String titulo;
  final int horarioHour;
  final int horarioMinute;
  final String categoria;
  final String observacoes;
  final String dosagem;

  const PrescriptionReminderItem({
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    required this.categoria,
    required this.observacoes,
    required this.dosagem,
  });

  factory PrescriptionReminderItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionReminderItem(
      titulo: json['titulo'] as String? ?? '',
      horarioHour: (json['horarioHour'] as num?)?.toInt() ?? 0,
      horarioMinute: (json['horarioMinute'] as num?)?.toInt() ?? 0,
      categoria: json['categoria'] as String? ?? 'medicacao',
      observacoes: json['observacoes'] as String? ?? '',
      dosagem: json['dosagem'] as String? ?? '',
    );
  }
}

class PrescriptionParserResult {
  final List<PrescriptionReminderItem> lembretes;
  final String erro;

  const PrescriptionParserResult({this.lembretes = const [], this.erro = ''});

  bool get hasError => erro.isNotEmpty;
  bool get success => !hasError && lembretes.isNotEmpty;

  factory PrescriptionParserResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['lembretes'];
    final list = rawList is List ? rawList : const [];
    final items = list
        .whereType<Map>()
        .map(
          (item) => PrescriptionReminderItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    return PrescriptionParserResult(
      lembretes: items,
      erro: json['erro'] as String? ?? '',
    );
  }
}

class PrescriptionParserService {
  PrescriptionParserService._();
  static final PrescriptionParserService instance =
      PrescriptionParserService._();

  Future<PrescriptionParserResult> parse({required String imageBase64}) async {
    try {
      final function = FirebaseFunctions.instance.httpsCallable(
        'parsePrescription',
      );
      final result = await function.call({'imageBase64': imageBase64});

      final data = Map<String, dynamic>.from(result.data as Map);
      return PrescriptionParserResult.fromJson(data);
    } catch (e) {
      return PrescriptionParserResult(
        lembretes: [],
        erro: 'Erro ao processar receita médica: $e',
      );
    }
  }
}
