import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovement {
  final String id;
  final String elderlyId;
  final String reminderId;
  final String type;
  final int quantity;
  final int previousStock;
  final int resultingStock;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? expirationDate;
  final String note;

  const StockMovement({
    required this.id,
    required this.elderlyId,
    required this.reminderId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.resultingStock,
    required this.createdAt,
    required this.createdBy,
    this.expirationDate,
    this.note = '',
  });

  factory StockMovement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    DateTime readDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final expiration = data['validade'];
    return StockMovement(
      id: data['id'] as String? ?? document.id,
      elderlyId: data['idosoId'] as String? ?? '',
      reminderId: data['lembreteId'] as String? ?? '',
      type: data['tipo'] as String? ?? 'correcao',
      quantity: (data['quantidade'] as num?)?.toInt() ?? 0,
      previousStock: (data['estoqueAnterior'] as num?)?.toInt() ?? 0,
      resultingStock: (data['estoquePosterior'] as num?)?.toInt() ?? 0,
      createdAt: readDate(data['createdAt']),
      createdBy: data['createdBy'] as String? ?? '',
      expirationDate: expiration == null ? null : readDate(expiration),
      note: data['observacao'] as String? ?? '',
    );
  }
}
