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
  final bool failed;
  final String? lastError;

  OfflineWrite({
    required this.id,
    required this.collection,
    required this.docId,
    required this.action,
    required this.data,
    DateTime? createdAt,
    this.attempts = 0,
    this.failed = false,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  OfflineWrite copyWith({
    String? id,
    String? collection,
    String? docId,
    OfflineWriteAction? action,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? attempts,
    bool? failed,
    String? lastError,
  }) {
    return OfflineWrite(
      id: id ?? this.id,
      collection: collection ?? this.collection,
      docId: docId ?? this.docId,
      action: action ?? this.action,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      failed: failed ?? this.failed,
      lastError: lastError ?? this.lastError,
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
    'failed': failed,
    'lastError': lastError,
  };

  factory OfflineWrite.fromJson(Map<String, dynamic> json) {
    return OfflineWrite(
      id: json['id'] as String? ?? '',
      collection: json['collection'] as String? ?? '',
      docId: json['docId'] as String? ?? '',
      action: OfflineWriteAction.fromStorage(json['action'] as String?),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      failed: json['failed'] as bool? ?? false,
      lastError: json['lastError'] as String?,
    );
  }
}
