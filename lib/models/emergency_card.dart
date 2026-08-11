class EmergencyCard {
  final String name;
  final String allergies;
  final List<String> medications;
  final String contactName;
  final String contactPhone;
  final String note;
  final DateTime updatedAt;

  const EmergencyCard({
    required this.name,
    required this.allergies,
    required this.medications,
    required this.contactName,
    required this.contactPhone,
    required this.note,
    required this.updatedAt,
  });

  factory EmergencyCard.fromJson(Map<String, dynamic> json) {
    return EmergencyCard(
      name: json['name'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      medications: (json['medications'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .take(10)
          .toList(growable: false),
      contactName: json['contactName'] as String? ?? '',
      contactPhone: json['contactPhone'] as String? ?? '',
      note: json['note'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'allergies': allergies,
    'medications': medications,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'note': note,
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toQrJson() => {
    'schema': 'lembrete_amigo_emergency_v1',
    'name': name,
    'allergies': allergies,
    'medications': medications,
    'contact': contactName,
    'phone': contactPhone,
    'note': note,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
