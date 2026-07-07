enum VideoCallStatus {
  ringing,
  connected,
  ended,
  declined,
  missed;

  static VideoCallStatus fromString(String value) {
    return VideoCallStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VideoCallStatus.ended,
    );
  }
}

class VideoCall {
  final String id;
  final String roomName;
  final String idosoId;
  final String supervisorId;
  final VideoCallStatus status;
  final String initiatedBy;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  const VideoCall({
    required this.id,
    required this.roomName,
    required this.idosoId,
    required this.supervisorId,
    required this.status,
    required this.initiatedBy,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  bool get isFromSos => initiatedBy == 'sos';
  bool get isFromElderly => initiatedBy == 'idoso';
  bool get isFromSupervisor => initiatedBy == 'supervisor';

  Map<String, dynamic> toJson() => {
    'roomName': roomName,
    'idosoId': idosoId,
    'supervisorId': supervisorId,
    'status': status.name,
    'initiatedBy': initiatedBy,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };

  factory VideoCall.fromJson(String id, Map<String, dynamic> json) {
    return VideoCall(
      id: id,
      roomName: json['roomName'] as String? ?? '',
      idosoId: json['idosoId'] as String? ?? '',
      supervisorId: json['supervisorId'] as String? ?? '',
      status: VideoCallStatus.fromString(json['status'] as String? ?? 'ended'),
      initiatedBy: json['initiatedBy'] as String? ?? 'supervisor',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final min = durationSeconds! ~/ 60;
    final sec = durationSeconds! % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedStartTime {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    return '${startedAt.day}/${startedAt.month}/${startedAt.year}';
  }
}
