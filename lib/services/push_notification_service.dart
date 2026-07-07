import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_role_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.messageId} ${message.notification?.title}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  FirebaseMessaging? _messaging;
  String? _currentToken;
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageController.stream;

  /// Callback disparado quando chega uma notificação de chamada de vídeo.
  /// Recebe (callId, roomName).
  void Function(String callId, String roomName)? onVideoCallReceived;

  /// Callback disparado quando o app é aberto via notificação de vídeo.
  void Function(String callId, String roomName)? onVideoCallOpenedApp;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (!_useFirebase || kIsWeb) return;

    _messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      criticalAlert: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    _currentToken = await _messaging!.getToken();
    debugPrint('FCM token: $_currentToken');
    _saveToken();

    _messaging!.onTokenRefresh.listen((token) {
      _currentToken = token;
      _saveToken();
    });

    FirebaseMessaging.onMessage.listen((message) {
      _messageController.add(message);
      _handleVideoCallMessage(message, fromBackground: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _messageController.add(message);
      _handleVideoCallMessage(message, fromBackground: true);
    });
  }

  Future<void> _saveToken() async {
    if (!_useFirebase || _currentToken == null) return;
    try {
      final id = SessionRoleService.isSupervisor
          ? FirebaseAuth.instance.currentUser?.uid ?? ''
          : await SessionRoleService.getActiveIdosoId();
      if (id.isEmpty) return;

      final role = SessionRoleService.isSupervisor ? 'supervisor' : 'idoso';
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc('${role}_$id')
          .set({
        'token': _currentToken,
        'role': role,
        'userId': id,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erro ao salvar FCM token: $e');
    }
  }

  String? get currentToken => _currentToken;

  void _handleVideoCallMessage(RemoteMessage message, {required bool fromBackground}) {
    if (message.data['type'] != 'video_call') return;

    final callId = message.data['callId'] as String?;
    final roomName = message.data['roomName'] as String?;
    if (callId == null || roomName == null) return;

    if (fromBackground) {
      onVideoCallOpenedApp?.call(callId, roomName);
    } else {
      onVideoCallReceived?.call(callId, roomName);
    }
  }
}
