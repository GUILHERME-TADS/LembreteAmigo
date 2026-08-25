enum DeviceBarrierSeverity { info, warning, critical }

enum DeviceBarrierType {
  lowVolume,
  offline,
  pendingSync,
  inactiveApp,
  locationUnavailable,
  lowBattery,
  batteryOptimization,
}

class DeviceBarrier {
  final DeviceBarrierType type;
  final DeviceBarrierSeverity severity;
  final String title;
  final String message;
  final DateTime detectedAt;
  final int priority;
  final int? value;

  const DeviceBarrier({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.detectedAt,
    required this.priority,
    this.value,
  });

  String get key => type.name;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'message': message,
    'detectedAt': detectedAt.toIso8601String(),
    'priority': priority,
    'value': value,
  };

  factory DeviceBarrier.fromJson(Map<String, dynamic> json) {
    return DeviceBarrier(
      type: _typeFromName(json['type'] as String?),
      severity: _severityFromName(json['severity'] as String?),
      title: json['title'] as String? ?? 'Aviso do celular',
      message:
          json['message'] as String? ??
          'Existe uma condicao que pode atrapalhar os lembretes.',
      detectedAt:
          DateTime.tryParse(json['detectedAt'] as String? ?? '') ??
          DateTime.now(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      value: (json['value'] as num?)?.toInt(),
    );
  }

  static DeviceBarrierType _typeFromName(String? name) {
    return DeviceBarrierType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => DeviceBarrierType.inactiveApp,
    );
  }

  static DeviceBarrierSeverity _severityFromName(String? name) {
    return DeviceBarrierSeverity.values.firstWhere(
      (severity) => severity.name == name,
      orElse: () => DeviceBarrierSeverity.info,
    );
  }
}
