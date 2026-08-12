import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../main.dart';
import '../models/video_call.dart';
import '../utils/web_window_helper.dart';
import '../utils/firebase_helper.dart';
import 'app_status_service.dart';
import 'notification_service.dart';
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
  static const MethodChannel _jitsiChannel = MethodChannel(
    'com.example.lembretes_app/jitsi',
  );
  static Future<void>? _jitsiInitialization;

  final ValueNotifier<VideoCall?> activeCallNotifier = ValueNotifier(null);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  String? lastStartFailureMessage;

  DateTime? _joinedAt;
  String _joinedCallType = 'video';

  bool get _useFirebase => FirebaseHelper.isInitialized;

  Future<void> joinCall(
    String roomName, {
    required String callType,
    String? callId,
    bool alreadyVerified = false,
  }) async {
    try {
      if (callId != null && !alreadyVerified) {
        final canJoin = await _canJoinCall(callId, roomName);
        if (!canJoin) {
          AppStatusService.instance.report(
            id: 'video-call-denied',
            title: 'Chamada bloqueada',
            message:
                'Nao foi possivel confirmar permissao para entrar nesta chamada.',
            severity: AppStatusSeverity.critical,
          );
          return;
        }
      }
      final displayName = await getMyDisplayName();
      debugPrint(
        'Jitsi: entrando na chamada. Tipo: $callType, ID: $callId, Web: $kIsWeb',
      );

      _joinedAt = DateTime.now();
      _joinedCallType = callType;

      if (callId != null) {
        await watchCall(callId);
      }

      if (kIsWeb) {
        final isVoice = callType == 'voice';
        final encodedName = Uri.encodeComponent(displayName);
        final url =
            'https://meet.ffmuc.net/$roomName#config.prejoinPageEnabled=false&config.prejoinConfig.enabled=false&config.startWithVideoMuted=$isVoice&userInfo.displayName="$encodedName"';
        openJitsiWeb(url, callId, (id) => endCall(id));
        return;
      }
      await _ensureJitsiInitialized();
      final jitsiMeet = JitsiMeet();
      final isVoice = callType == 'voice';

      final eventListeners = JitsiMeetEventListener(
        conferenceTerminated: (url, error) {
          debugPrint('Jitsi: Conferência terminada: $url');
          if (callId != null) {
            endCall(callId);
          } else {
            _navigateToSummary(
              callerName: displayName,
              callType: callType,
              durationSeconds: _joinedAt != null
                  ? DateTime.now().difference(_joinedAt!).inSeconds
                  : 0,
              status: VideoCallStatus.ended,
            );
          }
        },
      );

      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.ffmuc.net',
        room: roomName,
        userInfo: JitsiMeetUserInfo(displayName: displayName),
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
      if (callId != null) {
        await endCall(callId);
      }
      AppStatusService.instance.report(
        id: 'video-call-join-error',
        title: 'Erro na chamada',
        message: 'Nao foi possivel abrir a sala de chamada neste aparelho.',
        severity: AppStatusSeverity.critical,
      );
    }
  }

  Future<void> _ensureJitsiInitialized() async {
    final currentInitialization = _jitsiInitialization;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final initialization = _jitsiChannel.invokeMethod<void>('initialize');
    _jitsiInitialization = initialization;

    try {
      await initialization;
    } catch (_) {
      if (identical(_jitsiInitialization, initialization)) {
        _jitsiInitialization = null;
      }
      rethrow;
    }
  }

  void _navigateToSummary({
    required String callerName,
    required String callType,
    required int durationSeconds,
    required VideoCallStatus status,
  }) {
    try {
      final navState = navigatorKey.currentState;
      if (navState != null) {
        navState.pushNamed(
          '/post-call-summary',
          arguments: {
            'callerName': callerName,
            'callType': callType,
            'durationSeconds': durationSeconds,
            'status': status,
          },
        );
      }
    } catch (e) {
      debugPrint('Erro ao abrir resumo pós-chamada: $e');
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
            return doc.data()?['nome'] as String? ?? 'Cuidador';
          }
        }
        return 'Cuidador';
      } else {
        final idosoId = await SessionRoleService.getActiveIdosoId();
        if (!SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
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
      return SessionRoleService.isSupervisor ? 'Cuidador' : 'Idoso';
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
    final secureRandom = Random.secure();
    final random = [
      secureRandom.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
      secureRandom.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ].join();
    return 'call_${timestamp}_$random';
  }

  Future<bool> _canJoinCall(String callId, String roomName) async {
    if (!_useFirebase) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('video_calls')
          .doc(callId)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      if (!doc.exists || data == null) return false;
      if (data['roomName'] != roomName) return false;
      final status = data['status'] as String? ?? '';
      if (status != 'ringing' && status != 'connected') return false;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final idosoId = data['idosoId'] as String? ?? '';
      final supervisorId = data['supervisorId'] as String? ?? '';
      if (uid != null && (uid == idosoId || uid == supervisorId)) {
        return true;
      }
      final verifiedIdoso = await SessionRoleService.getVerifiedActiveIdosoId();
      return verifiedIdoso != null && verifiedIdoso == idosoId;
    } catch (e) {
      debugPrint('Erro ao validar entrada na chamada: $e');
      return false;
    }
  }

  Future<VideoCallStart?> initiateCall({
    required String idosoId,
    String initiatedBy = 'supervisor',
    required String callType,
  }) async {
    lastStartFailureMessage = null;

    if (!_useFirebase) {
      debugPrint(
        'Chamada nao iniciada: Firebase indisponivel para notificar o outro aparelho.',
      );
      lastStartFailureMessage =
          'Firebase indisponivel para iniciar a chamada neste aparelho.';
      AppStatusService.instance.report(
        id: 'video-call-no-firebase',
        title: 'Chamada indisponivel',
        message:
            'Nao foi possivel conectar ao Firebase para iniciar a chamada.',
        severity: AppStatusSeverity.critical,
      );
      return null;
    }

    final canUse = await SessionRoleService.canUseActiveIdoso();
    if (!canUse) {
      final activeIdosoId = await SessionRoleService.getActiveIdosoId();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sem login';
      lastStartFailureMessage =
          'Vinculo nao validado. Idoso ativo: $activeIdosoId. Usuario Firebase: $uid.';
      debugPrint('Chamada nao iniciada: $lastStartFailureMessage');
      AppStatusService.instance.report(
        id: 'video-call-invalid-session',
        title: 'Chamada indisponivel',
        message:
            'Confirme o vinculo entre os aparelhos antes de iniciar chamada.',
        severity: AppStatusSeverity.critical,
      );
      return null;
    }

    final roomName = _generateRoomName(idosoId);
    final callId = 'vc_${DateTime.now().millisecondsSinceEpoch}';
    final callerName = await getMyDisplayName();

    try {
      final supervisorId = await _getSupervisorId();
      if (supervisorId.isEmpty) {
        debugPrint('Chamada nao iniciada: nenhum supervisor vinculado.');
        lastStartFailureMessage =
            'Nenhum cuidador ativo foi encontrado para este idoso.';
        AppStatusService.instance.report(
          id: 'video-call-no-supervisor',
          title: 'Cuidador nao encontrado',
          message: 'O perfil do idoso nao tem um cuidador ativo vinculado.',
          severity: AppStatusSeverity.critical,
        );
        return null;
      }

      final callData = {
        'roomName': roomName,
        'idosoId': idosoId,
        'supervisorId': supervisorId,
        'status': 'ringing',
        'initiatedBy': initiatedBy,
        'callType': callType,
        'startedAt': DateTime.now().toIso8601String(),
        'callerName': callerName,
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
        callerName: callerName,
      );
      unawaited(_markMissedAfterTimeout(callId));
    } catch (e) {
      debugPrint('Erro ao registrar chamada no Firestore: $e');
      lastStartFailureMessage =
          'Não foi possível iniciar a chamada agora. Tente novamente.';
      AppStatusService.instance.report(
        id: 'video-call-create-error',
        title: 'Erro ao criar chamada',
        message: 'Não foi possível iniciar a chamada agora. Tente novamente.',
        severity: AppStatusSeverity.critical,
      );
      return null;
    }

    return VideoCallStart(callId: callId, roomName: roomName);
  }

  Future<void> _markMissedAfterTimeout(String callId) async {
    await Future<void>.delayed(const Duration(seconds: 45));
    if (!_useFirebase) return;
    try {
      final reference = FirebaseFirestore.instance
          .collection('video_calls')
          .doc(callId);
      final snapshot = await reference.get();
      if (!snapshot.exists || snapshot.data()?['status'] != 'ringing') return;
      await reference.update({
        'status': 'missed',
        'endedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erro ao encerrar chamada não atendida: $e');
    }
  }

  Future<void> _sendCallPushNotification({
    required String idosoId,
    required String callId,
    required String roomName,
    required String initiatedBy,
    required String callType,
    required String callerName,
  }) async {
    if (!_useFirebase) return;

    final targetRole = SessionRoleService.isSupervisor
        ? 'elderly'
        : 'supervisor';
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
      await FirebaseFunctions.instance.httpsCallable('sendPush').call({
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
          'callerName': callerName,
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
              call.status == VideoCallStatus.declined ||
              call.status == VideoCallStatus.missed) {
            NotificationService.instance.cancelarChamada(callId);
            if (call.status == VideoCallStatus.missed) {
              NotificationService.instance.mostrarChamadaPerdida(
                callId: callId,
                callType: call.callType,
              );
            }
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
    await NotificationService.instance.cancelarChamada(callId);
    if (!_useFirebase) return;
    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .update({'status': 'connected'});
  }

  /// Recusa uma chamada
  Future<void> declineCall(String callId) async {
    await NotificationService.instance.cancelarChamada(callId);
    if (!_useFirebase) return;
    await FirebaseFirestore.instance
        .collection('video_calls')
        .doc(callId)
        .update({
          'status': 'declined',
          'endedAt': DateTime.now().toIso8601String(),
        });
    await _callSubscription?.cancel();
    activeCallNotifier.value = null;
  }

  /// Encerra uma chamada
  Future<void> endCall(String callId, {int? durationSeconds}) async {
    await NotificationService.instance.cancelarChamada(callId);
    final calculatedDuration =
        durationSeconds ??
        (_joinedAt != null
            ? DateTime.now().difference(_joinedAt!).inSeconds
            : 0);
    final displayName = await getMyDisplayName();

    if (_useFirebase) {
      final update = <String, dynamic>{
        'status': 'ended',
        'endedAt': DateTime.now().toIso8601String(),
        'durationSeconds': calculatedDuration,
      };
      await FirebaseFirestore.instance
          .collection('video_calls')
          .doc(callId)
          .update(update);
    }

    await _callSubscription?.cancel();
    activeCallNotifier.value = null;

    _navigateToSummary(
      callerName: displayName,
      callType: _joinedCallType,
      durationSeconds: calculatedDuration,
      status: VideoCallStatus.ended,
    );

    _joinedAt = null;
  }

  /// Busca o histórico de chamadas de um idoso
  Stream<List<VideoCall>> watchCallHistory(String idosoId) {
    return FirebaseFirestore.instance
        .collection('video_calls')
        .where('idosoId', isEqualTo: idosoId)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return VideoCall.fromJson(doc.id, doc.data());
          }).toList(),
        );
  }

  /// Stream que monitora a quantidade de chamadas perdidas não lidas (status: missed e seen != true)
  Stream<int> watchMissedCallsCount() async* {
    if (!_useFirebase) {
      yield 0;
      return;
    }
    final idosoId = await _getIdosoId();
    if (idosoId.isEmpty) {
      yield 0;
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('video_calls')
        .where('idosoId', isEqualTo: idosoId)
        .where('status', isEqualTo: 'missed')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.where((doc) => doc.data()['seen'] != true).length,
        );
  }

  /// Marca todas as chamadas perdidas como lidas
  Future<void> markMissedCallsAsRead() async {
    if (!_useFirebase) return;
    try {
      final idosoId = await _getIdosoId();
      if (idosoId.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('video_calls')
          .where('idosoId', isEqualTo: idosoId)
          .where('status', isEqualTo: 'missed')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      var hasUpdates = false;

      for (final doc in snapshot.docs) {
        if (doc.data()['seen'] != true) {
          batch.update(doc.reference, {'seen': true});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Erro ao marcar chamadas perdidas como lidas: $e');
    }
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

  /// Remove uma chamada do histórico no Firestore
  Future<bool> deleteCall(String callId) async {
    if (!_useFirebase) return false;
    try {
      await FirebaseFirestore.instance
          .collection('video_calls')
          .doc(callId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Erro ao deletar chamada $callId: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _callSubscription?.cancel();
    activeCallNotifier.value = null;
  }
}
