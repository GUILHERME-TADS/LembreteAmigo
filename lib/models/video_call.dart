import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String callType; // 'video' or 'voice'
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
    required this.callType,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  bool get isFromSos => initiatedBy == 'sos';
  bool get isFromElderly => initiatedBy == 'idoso';
  bool get isFromSupervisor => initiatedBy == 'supervisor';
  bool get isVoiceCall => callType == 'voice';

  Map<String, dynamic> toJson() => {
    'roomName': roomName,
    'idosoId': idosoId,
    'supervisorId': supervisorId,
    'status': status.name,
    'initiatedBy': initiatedBy,
    'callType': callType,
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
      callType: json['callType'] as String? ?? 'video',
      startedAt: _parseDateTime(json['startedAt']) ?? DateTime.now(),
      endedAt: _parseDateTime(json['endedAt']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) return '00:00';
    final min = durationSeconds! ~/ 60;
    final sec = durationSeconds! % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedDetailedDuration {
    if (durationSeconds == null || durationSeconds == 0) {
      if (status == VideoCallStatus.declined) return 'Chamada recusada';
      if (status == VideoCallStatus.missed) return 'Chamada não atendida';
      return 'Duração rápida';
    }
    final min = durationSeconds! ~/ 60;
    final sec = durationSeconds! % 60;
    if (min == 0) {
      return '$sec segundos';
    } else if (sec == 0) {
      return '$min min';
    } else {
      return '$min min $sec s';
    }
  }

  String get statusDescription {
    switch (status) {
      case VideoCallStatus.ringing:
        return 'Chamando...';
      case VideoCallStatus.connected:
        return 'Em andamento';
      case VideoCallStatus.ended:
        return 'Chamada concluída';
      case VideoCallStatus.declined:
        return 'Chamada recusada';
      case VideoCallStatus.missed:
        return 'Chamada não atendida';
    }
  }

  String get formattedStartTime {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    return '${startedAt.day.toString().padLeft(2, '0')}/${startedAt.month.toString().padLeft(2, '0')}/${startedAt.year}';
  }
}
