import 'device_barrier.dart';

class DeviceDiagnostics {
  final List<DeviceBarrier> barriers;
  final int? batteryLevel;
  final String? batteryState;
  final DateTime? updatedAt;
  final DateTime? lastAlarmTestAt;
  final bool? lastAlarmTestSuccessful;

  const DeviceDiagnostics({
    required this.barriers,
    this.batteryLevel,
    this.batteryState,
    this.updatedAt,
    this.lastAlarmTestAt,
    this.lastAlarmTestSuccessful,
  });

  Map<String, dynamic> toJson() => {
    'barriers': barriers.map((b) => b.toJson()).toList(),
    'batteryLevel': batteryLevel,
    'batteryState': batteryState,
    'updatedAt': updatedAt?.toIso8601String(),
    'lastAlarmTestAt': lastAlarmTestAt?.toIso8601String(),
    'lastAlarmTestSuccessful': lastAlarmTestSuccessful,
  };

  factory DeviceDiagnostics.fromJson(Map<String, dynamic> json) {
    final rawBarriers = json['barriers'] is List
        ? json['barriers'] as List
        : const [];
    final barriers = rawBarriers
        .whereType<Map>()
        .map((item) => DeviceBarrier.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final updatedAtStr = json['updatedAt'] as String?;
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr)
        : null;

    return DeviceDiagnostics(
      barriers: barriers,
      batteryLevel: (json['batteryLevel'] as num?)?.toInt(),
      batteryState: json['batteryState'] as String?,
      updatedAt: updatedAt,
      lastAlarmTestAt: DateTime.tryParse(
        json['lastAlarmTestAt'] as String? ?? '',
      ),
      lastAlarmTestSuccessful: json['lastAlarmTestSuccessful'] as bool?,
    );
  }
}
