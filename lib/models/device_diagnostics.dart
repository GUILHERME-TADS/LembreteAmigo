import 'device_barrier.dart';

class DeviceDiagnostics {
  final List<DeviceBarrier> barriers;
  final int? batteryLevel;
  final String? batteryState;
  final DateTime? updatedAt;

  const DeviceDiagnostics({
    required this.barriers,
    this.batteryLevel,
    this.batteryState,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'barriers': barriers.map((b) => b.toJson()).toList(),
        'batteryLevel': batteryLevel,
        'batteryState': batteryState,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory DeviceDiagnostics.fromJson(Map<String, dynamic> json) {
    final rawBarriers =
        json['barriers'] is List ? json['barriers'] as List : const [];
    final barriers = rawBarriers
        .whereType<Map>()
        .map((item) => DeviceBarrier.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final updatedAtStr = json['updatedAt'] as String?;
    final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;

    return DeviceDiagnostics(
      barriers: barriers,
      batteryLevel: (json['batteryLevel'] as num?)?.toInt(),
      batteryState: json['batteryState'] as String?,
      updatedAt: updatedAt,
    );
  }
}
