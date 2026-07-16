import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/video_call.dart';
import '../utils/web_window_helper.dart';
import 'session_role_service.dart';

// Removed VideoCallToken as it's no longer needed for Jitsi

class VideoCallStart {
  final String callId;
  final String roomName;

  const VideoCallStart({required this.callId, required this.roomName});
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

  Future<void> joinCall(String roomName, {required String callType, String? callId}) async {
    try {
      final displayName = await getMyDisplayName();
      debugPrint('Jitsi debug: Entrando na chamada. Tipo: $callType, Sala: $roomName, ID: $callId, Nome: $displayName, Web: $kIsWeb');

      if (callId != null) {
        watchCall(callId);
      }

      if (kIsWeb) {
        final isVoice = callType == 'voice';
        final encodedName = Uri.encodeComponent(displayName);
        final url = 'https://meet.ffmuc.net/$roomName#config.prejoinPageEnabled=false&config.prejoinConfig.enabled=false&config.startWithVideoMuted=$isVoice&userInfo.displayName="$encodedName"';
        debugPrint('Jitsi debug Web URL: $url');
        openJitsiWeb(url, callId, (id) => endCall(id));
        return;
      }
      final jitsiMeet = JitsiMeet();
      final isVoice = callType == 'voice';

      final eventListeners = JitsiMeetEventListener(
        conferenceTerminated: (url, error) {
          debugPrint('Jitsi: Conferência terminada: $url');
          if (callId != null) {
            endCall(callId);
          }
        },
      );

      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.ffmuc.net',
        room: roomName,
        userInfo: JitsiMeetUserInfo(
          displayName: displayName,
        ),
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": isVoice,
          "prejoinPageEnabled": false,
          "prejoinConfig.enabled": false,
        },
        featureFlags: {
          "welcomepage.enabled": false,
          if (isVoice) ...{
            "video-mute.enabled": false,
            "audio-only.enabled": true,
          },
        },
      );
      await jitsiMeet.join(options, eventListeners);
    } catch (e) {
      debugPrint('Erro ao entrar na chamada Jitsi: $e');
    }
  }

  Future<String> getMyIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;
    return SessionRoleService.getActiveIdosoId();
  }

  Future<String> getMyDisplayName() async {
    try {
      if (SessionRoleService.isSupervisor) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(uid)
              .get();
          if (doc.exists && doc.data() != null) {
            return doc.data()?['nome'] as String? ?? 'Supervisor';
          }
        }
        return 'Supervisor';
      } else {
        final idosoId = await SessionRoleService.getActiveIdosoId();
        if (idosoId != SessionRoleService.unpairedIdosoId) {
          final doc = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .get();
          if (doc.exists && doc.data() != null) {
            return doc.data()?['nome'] as String? ?? 'Idoso';
          }
        }
        return 'Idoso';
      }
    } catch (_) {
      return SessionRoleService.isSupervisor ? 'Supervisor' : 'Idoso';
    }
  }

  Future<String> _getIdosoId() async {
    return SessionRoleService.getActiveIdosoId();
  }

  Future<String> _getSupervisorId() async {
    if (SessionRoleService.isSupervisor) {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    final idosoId = await _getIdosoId();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .get();
      return doc.data()?['supervisorId'] as String? ?? '';
    } catch (e) {
      debugPrint('Erro ao buscar supervisor vinculado: $e');
      return '';
    }
  }

  String _generateRoomName(String idosoId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'call_${idosoId}_$timestamp$random';
  }

  Future<VideoCallStart?> initiateCall({
    required String idosoId,
    String initiatedBy = 'supervisor',
    required String callType,
  }) async {
    if (!_useFirebase) {
      debugPrint('Chamada nao iniciada: Firebase indisponivel para notificar o outro aparelho.');
      return null;
    }

    final roomName = _generateRoomName(idosoId);
    final callId = 'vc_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final supervisorId = await _getSupervisorId();
      if (supervisorId.isEmpty) {
        debugPrint('Chamada nao iniciada: nenhum supervisor vinculado.');
        return null;
      }

      final callData = {
        'roomName': roomName,
        'idosoId': idosoId,
        'supervisorId': supervisorId,
        'status': 'ringing',
        'initiatedBy': initiatedBy,
        'callType': callType,
        'startedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('video_calls')
          .doc(callId)
          .set(callData);

      await _sendCallPushNotification(
        idosoId: idosoId,
        callId: callId,
        roomName: roomName,
        initiatedBy: initiatedBy,
        callType: callType,
      );
    } catch (e) {
      debugPrint('Erro ao registrar chamada no Firestore: $e');
      return null;
    }

    return VideoCallStart(callId: callId, roomName: roomName);
  }

  Future<void> _sendCallPushNotification({
    required String idosoId,
    required String callId,
    required String roomName,
    required String initiatedBy,
    required String callType,
  }) async {
    if (!_useFirebase) return;

    final targetRole = SessionRoleService.isSupervisor ? 'elderly' : 'supervisor';
    String targetUserId;
    if (SessionRoleService.isSupervisor) {
      targetUserId = idosoId;
    } else {
      targetUserId = await _getSupervisorId();
    }

    if (targetUserId.isEmpty) return;

    final isVoice = callType == 'voice';
    final titleText = isVoice ? 'Chamada de Voz' : 'Chamada de Vídeo';
    final bodyText = isVoice
        ? 'Você está recebendo uma chamada de voz!'
        : 'Você está recebendo uma chamada de vídeo!';

    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendPush')
          .call({
        'targetUserId': targetUserId,
        'targetRole': targetRole,
        'title': titleText,
        'body': bodyText,
        'data': {
          'type': 'video_call',
          'callId': callId,
          'roomName': roomName,
          'initiatedBy': initiatedBy,
          'callType': callType,
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
      final data = snapshot.data();
      if (data == null) {
        activeCallNotifier.value = null;
        return;
      }
      final call = VideoCall.fromJson(callId, data);
      activeCallNotifier.value = call;

      // If call is ended or declined, terminate Jitsi on both Web and Mobile
      if (call.status == VideoCallStatus.ended ||
          call.status == VideoCallStatus.declined) {
        if (kIsWeb) {
          closeJitsiWeb();
        } else {
          JitsiMeet().hangUp();
        }
        _callSubscription?.cancel();
        activeCallNotifier.value = null;
      }
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

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('video_calls')
        .where('status', whereIn: ['ringing', 'connected']);

    if (SessionRoleService.isSupervisor && supervisorId.isNotEmpty) {
      query = query.where('supervisorId', isEqualTo: supervisorId);
    } else if (idosoId.isNotEmpty) {
      query = query.where('idosoId', isEqualTo: idosoId);
    } else {
      return [];
    }

    final snapshot = await query.get();

    final calls = snapshot.docs
        .map((doc) => VideoCall.fromJson(doc.id, doc.data()))
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
