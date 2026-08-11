import 'package:cloud_firestore/cloud_firestore.dart';

enum CareAlertStatus { open, acknowledged, resolved }

class CareAlert {
  final String id;
  final String elderlyId;
  final String type;
  final String title;
  final String message;
  final int severity;
  final CareAlertStatus status;
  final DateTime createdAt;
  final String? responsibleId;
  final String? sourceId;
  final String? resolution;
  final int escalationLevel;
  final String? deliveryStatus;

  const CareAlert({
    required this.id,
    required this.elderlyId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.responsibleId,
    this.sourceId,
    this.resolution,
    this.escalationLevel = 0,
    this.deliveryStatus,
  });

  bool get isOpen => status == CareAlertStatus.open;
  bool get isAcknowledged => status == CareAlertStatus.acknowledged;
  bool get isResolved => status == CareAlertStatus.resolved;

  factory CareAlert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CareAlert.fromMap(document.id, data);
  }

  factory CareAlert.fromMap(String documentId, Map<String, dynamic> data) {
    return CareAlert(
      id: (data['id'] as String?)?.isNotEmpty == true
          ? data['id'] as String
          : documentId,
      elderlyId: data['idosoId'] as String? ?? '',
      type: data['tipo'] as String? ?? 'general',
      title: data['titulo'] as String? ?? 'Pendência',
      message: data['mensagem'] as String? ?? '',
      severity: ((data['severidade'] as num?)?.toInt() ?? 1).clamp(1, 3),
      status: _statusFromStorage(data['status'] as String?),
      createdAt: _dateFromValue(data['createdAt'] ?? data['criadoEm']),
      responsibleId: data['responsavelId'] as String?,
      sourceId: data['origemId'] as String?,
      resolution: data['resolucao'] as String?,
      escalationLevel: (data['nivelEscalonamento'] as num?)?.toInt() ?? 0,
      deliveryStatus: data['deliveryStatus'] as String?,
    );
  }

  static CareAlertStatus _statusFromStorage(String? value) {
    return switch (value) {
      'acknowledged' => CareAlertStatus.acknowledged,
      'resolved' => CareAlertStatus.resolved,
      _ => CareAlertStatus.open,
    };
  }

  static DateTime _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
