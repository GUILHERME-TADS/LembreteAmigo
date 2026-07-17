import 'package:flutter/foundation.dart';

enum AppStatusSeverity { info, warning, critical }

class AppStatusMessage {
  final String id;
  final String title;
  final String message;
  final AppStatusSeverity severity;
  final DateTime createdAt;

  AppStatusMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AppStatusService {
  AppStatusService._();
  static final AppStatusService instance = AppStatusService._();

  final ValueNotifier<List<AppStatusMessage>> messages =
      ValueNotifier<List<AppStatusMessage>>(<AppStatusMessage>[]);

  void report({
    required String id,
    required String title,
    required String message,
    AppStatusSeverity severity = AppStatusSeverity.warning,
  }) {
    final current = List<AppStatusMessage>.from(messages.value)
      ..removeWhere((item) => item.id == id);
    current.insert(
      0,
      AppStatusMessage(
        id: id,
        title: title,
        message: message,
        severity: severity,
      ),
    );
    messages.value = current.take(8).toList();
  }

  void clear(String id) {
    messages.value = messages.value.where((item) => item.id != id).toList();
  }
}
