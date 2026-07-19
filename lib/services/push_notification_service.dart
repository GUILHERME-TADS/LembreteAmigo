import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/session_role_service.dart';
import '../services/app_status_service.dart';
import '../services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    'FCM background: ${message.messageId} ${message.notification?.title}',
  );
  if (message.data['type'] != 'video_call') return;

  final callId = message.data['callId'];
  final roomName = message.data['roomName'];
  final callType = message.data['callType'] ?? 'video';
  final callerName = message.data['callerName'];
  if (callId == null ||
      callId.isEmpty ||
      roomName == null ||
      roomName.isEmpty) {
    return;
  }

  final plugin = FlutterLocalNotificationsPlugin();
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await plugin.initialize(settings);
  await NotificationService.showIncomingCallNotification(
    plugin: plugin,
    callId: callId,
    roomName: roomName,
    callType: callType,
    callerName: callerName,
  );
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

  /// Callback disparado quando chega uma notificação de chamada de vídeo/voz.
  /// Recebe (callId, roomName, callType).
  void Function(String callId, String roomName, String callType)?
  onVideoCallReceived;

  /// Callback disparado quando o app é aberto via notificação de vídeo/voz.
  void Function(String callId, String roomName, String callType)?
  onVideoCallOpenedApp;

  void Function(String messageId)? onAppMessageOpened;

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
      _handleAppMessage(message, opened: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _messageController.add(message);
      _handleVideoCallMessage(message, fromBackground: true);
      _handleAppMessage(message, opened: true);
    });

    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleVideoCallMessage(initialMessage, fromBackground: true);
      _handleAppMessage(initialMessage, opened: true);
    }
  }

  Future<void> _saveToken() async {
    if (!_useFirebase || _currentToken == null) return;
    try {
      if (SessionRoleService.isElderly &&
          !await SessionRoleService.canSyncElderlyPrivateData()) {
        return;
      }
      final id = SessionRoleService.isSupervisor
          ? FirebaseAuth.instance.currentUser?.uid ?? ''
          : await SessionRoleService.getVerifiedActiveIdosoId() ?? '';
      if (id.isEmpty ||
          (!SessionRoleService.isSupervisor &&
              SessionRoleService.isLocalOnlyIdosoId(id))) {
        return;
      }

      final role = SessionRoleService.isSupervisor ? 'supervisor' : 'elderly';
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
      AppStatusService.instance.report(
        id: 'fcm-token',
        title: 'Avisos podem falhar',
        message: 'Nao foi possivel registrar este aparelho para notificacoes.',
      );
    }
  }

  Future<void> saveCurrentToken() => _saveToken();

  String? get currentToken => _currentToken;

  void _handleVideoCallMessage(
    RemoteMessage message, {
    required bool fromBackground,
  }) {
    if (message.data['type'] != 'video_call') return;

    final callId = message.data['callId'] as String?;
    final roomName = message.data['roomName'] as String?;
    final callType = message.data['callType'] as String? ?? 'video';
    final callerName = message.data['callerName'] as String?;
    if (callId == null || roomName == null) return;

    if (fromBackground) {
      onVideoCallOpenedApp?.call(callId, roomName, callType);
    } else {
      NotificationService.instance.mostrarChamadaRecebida(
        callId: callId,
        roomName: roomName,
        callType: callType,
        callerName: callerName,
      );
      onVideoCallReceived?.call(callId, roomName, callType);
    }
  }

  void _handleAppMessage(RemoteMessage message, {required bool opened}) {
    if (message.data['type'] != 'app_message') return;
    final messageId = message.data['messageId'] as String? ?? message.messageId;
    if (messageId == null || messageId.isEmpty) return;
    if (opened) {
      onAppMessageOpened?.call(messageId);
      return;
    }

    final title = message.notification?.title ?? 'Novo recado';
    final body = message.notification?.body ?? 'Você recebeu um novo recado.';
    NotificationService.instance.mostrarNovoRecado(
      messageId: messageId,
      title: title,
      body: body,
    );
  }
}
