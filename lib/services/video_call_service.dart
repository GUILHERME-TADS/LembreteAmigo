import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/video_call.dart';
import 'session_role_service.dart';

class VideoCallToken {
  final String token;
  final String serverUrl;

  const VideoCallToken({required this.token, required this.serverUrl});
}

class VideoCallService {
  VideoCallService._();
  static final VideoCallService instance = VideoCallService._();

  final ValueNotifier<VideoCall?> activeCallNotifier = ValueNotifier(null);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<VideoCallToken?> generateToken({
    required String roomName,
    required String identity,
    String metadata = '',
  }) async {
    if (!_useFirebase) return null;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateVideoToken')
          .call({
        'roomName': roomName,
        'identity': identity,
        'metadata': metadata,
      });

      final data = result.data as Map<String, dynamic>;
      return VideoCallToken(
        token: data['token'] as String,
        serverUrl: data['serverUrl'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Erro ao gerar token de video: $e');
      return null;
    }
  }

  Future<String> getMyIdentity() async {
    if (SessionRoleService.isSupervisor) {
      final user = FirebaseAuth.instance.currentUser;
      return 'supervisor_${user?.uid ?? 'unknown'}';
    }
    final idosoId = await SessionRoleService.getActiveIdosoId();
    return 'idoso_$idosoId';
  }

  Future<String> _getIdosoId() async {
    return SessionRoleService.getActiveIdosoId();
  }

  Future<String> _getSupervisorId() async {
    if (SessionRoleService.isSupervisor) {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    return '';
  }

  String _generateRoomName(String idosoId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'call_${idosoId}_$timestamp$random';
  }

  /// Inicia uma chamada de vídeo. Retorna o callId.
  Future<String?> initiateCall({
    required String idosoId,
    String initiatedBy = 'supervisor',
  }) async {
    if (!_useFirebase) return null;

    final roomName = _generateRoomName(idosoId);
    final supervisorId = await _getSupervisorId();
    final callId = 'vc_${DateTime.now().millisecondsSinceEpoch}';

    final callData = {
      'roomName': roomName,
      'idosoId': idosoId,
      'supervisorId': supervisorId,
      'status': 'ringing',
      'initiatedBy': initiatedBy,
      'startedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .set(callData);

    // Notifica o outro lado via FCM
    await _sendCallPushNotification(
      idosoId: idosoId,
      callId: callId,
      roomName: roomName,
      initiatedBy: initiatedBy,
    );

    return callId;
  }

  Future<void> _sendCallPushNotification({
    required String idosoId,
    required String callId,
    required String roomName,
    required String initiatedBy,
  }) async {
    if (!_useFirebase) return;

    final targetRole = SessionRoleService.isSupervisor ? 'idoso' : 'supervisor';
    String targetUserId;
    if (SessionRoleService.isSupervisor) {
      targetUserId = idosoId;
    } else {
      targetUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }

    if (targetUserId.isEmpty) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendPush')
          .call({
        'targetUserId': targetUserId,
        'targetRole': targetRole,
        'title': 'Chamada de Vídeo',
        'body': SessionRoleService.isSupervisor
            ? 'Iniciando chamada de vídeo...'
            : 'Você está recebendo uma chamada de vídeo!',
        'data': {
          'type': 'video_call',
          'callId': callId,
          'roomName': roomName,
          'initiatedBy': initiatedBy,
        },
      });
    } catch (e) {
      debugPrint('Erro ao enviar push de chamada: $e');
    }
  }

  /// Escuta mudanças no status de uma chamada
  Future<void> watchCall(String callId) async {
    await _callSubscription?.cancel();
    _callSubscription = FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        activeCallNotifier.value = null;
        return;
      }
      final data = snapshot.data()!;
      activeCallNotifier.value = VideoCall.fromJson(callId, data);
    });
  }

  /// Aceita uma chamada
  Future<void> acceptCall(String callId) async {
    if (!_useFirebase) return;
    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .update({'status': 'connected'});
  }

  /// Recusa uma chamada
  Future<void> declineCall(String callId) async {
    if (!_useFirebase) return;
    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .update({
      'status': 'declined',
      'endedAt': FieldValue.serverTimestamp(),
    });
    await _callSubscription?.cancel();
    activeCallNotifier.value = null;
  }

  /// Encerra uma chamada
  Future<void> endCall(String callId, {int? durationSeconds}) async {
    if (!_useFirebase) return;
    final update = <String, dynamic>{
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    };
    if (durationSeconds != null) {
      update['durationSeconds'] = durationSeconds;
    }
    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .update(update);
    await _callSubscription?.cancel();
    activeCallNotifier.value = null;
  }

  /// Busca o histórico de chamadas de um idoso
  Stream<List<VideoCall>> watchCallHistory(String idosoId) {
    return FirebaseFirestore.instance
        .collection('video_calls')
        .where('idosoId', isEqualTo: idosoId)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return VideoCall.fromJson(doc.id, doc.data());
            }).toList());
  }

  /// Busca chamadas ativas (ringing ou connected) para um idoso/supervisor
  Future<List<VideoCall>> getActiveCalls() async {
    if (!_useFirebase) return [];

    final idosoId = await _getIdosoId();
    final supervisorId = await _getSupervisorId();

    final snapshot = await FirebaseFirestore.instance
        .collection('video_calls')
        .where('status', whereIn: ['ringing', 'connected'])
        .get();

    final calls = snapshot.docs
        .map((doc) => VideoCall.fromJson(doc.id, doc.data()))
        .where((call) =>
            call.idosoId == idosoId || call.supervisorId == supervisorId)
        .toList();

    // Se encontrar uma chamada ringing, começa a escutar
    if (calls.isNotEmpty) {
      await watchCall(calls.first.id);
    }

    return calls;
  }

  Future<void> dispose() async {
    await _callSubscription?.cancel();
    activeCallNotifier.value = null;
  }
}
