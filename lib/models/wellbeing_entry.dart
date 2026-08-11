import 'package:cloud_firestore/cloud_firestore.dart';

class WellbeingEntry {
  final String id;
  final String elderlyId;
  final int mood;
  final List<String> symptoms;
  final String note;
  final String transcript;
  final bool needsHelp;
  final DateTime createdAt;
  final String createdBy;

  const WellbeingEntry({
    required this.id,
    required this.elderlyId,
    required this.mood,
    required this.symptoms,
    required this.needsHelp,
    required this.createdAt,
    required this.createdBy,
    this.note = '',
    this.transcript = '',
  });

  factory WellbeingEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return WellbeingEntry.fromMap(
      document.id,
      document.data() ?? const <String, dynamic>{},
    );
  }

  factory WellbeingEntry.fromMap(String documentId, Map<String, dynamic> data) {
    final rawDate = data['createdAt'];
    final createdAt = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();
    return WellbeingEntry(
      id: data['id'] as String? ?? documentId,
      elderlyId: data['idosoId'] as String? ?? '',
      mood: ((data['humor'] as num?)?.toInt() ?? 3).clamp(1, 5),
      symptoms: (data['sintomas'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .take(12)
          .toList(growable: false),
      note: data['observacao'] as String? ?? '',
      transcript: data['transcricao'] as String? ?? '',
      needsHelp: data['precisaAjuda'] as bool? ?? false,
      createdAt: createdAt,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'idosoId': elderlyId,
    'humor': mood,
    'sintomas': symptoms,
    'observacao': note,
    'transcricao': transcript,
    'precisaAjuda': needsHelp,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  Map<String, dynamic> toLocalJson() => {
    ...toFirestore(),
    'createdAt': createdAt.toIso8601String(),
  };
}
