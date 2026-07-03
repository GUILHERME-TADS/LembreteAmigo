enum OfflineWriteAction {
  set('set'),
  update('update'),
  delete('delete');

  final String storageValue;
  const OfflineWriteAction(this.storageValue);

  static OfflineWriteAction fromStorage(String? value) {
    return OfflineWriteAction.values.firstWhere(
      (action) => action.storageValue == value,
      orElse: () => OfflineWriteAction.set,
    );
  }
}

class OfflineWrite {
  final String id;
  final String collection;
  final String docId;
  final OfflineWriteAction action;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int attempts;

  OfflineWrite({
    required this.id,
    required this.collection,
    required this.docId,
    required this.action,
    required this.data,
    DateTime? createdAt,
    this.attempts = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  OfflineWrite copyWith({int? attempts}) {
    return OfflineWrite(
      id: id,
      collection: collection,
      docId: docId,
      action: action,
      data: data,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'docId': docId,
    'action': action.storageValue,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
  };

  factory OfflineWrite.fromJson(Map<String, dynamic> json) {
    return OfflineWrite(
      id: json['id'] as String,
      collection: json['collection'] as String,
      docId: json['docId'] as String,
      action: OfflineWriteAction.fromStorage(json['action'] as String?),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}
