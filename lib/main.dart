import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm/alarm.dart';

import 'models/lembrete.dart';
import 'models/video_call.dart';
import 'screens/active_reminder_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/all_reminders_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/elderly_help_screen.dart';
import 'screens/elderly_home_screen.dart';
import 'screens/elderly_onboarding_screen.dart';
import 'screens/elderly_pairing_screen.dart';
import 'screens/elderly_profile_screen.dart';
import 'screens/emergency_alert_screen.dart';
import 'screens/identify_medication_screen.dart';
import 'screens/reminder_detail_screen.dart';
import 'screens/incoming_video_call_screen.dart';
import 'screens/post_call_summary_screen.dart';
import 'screens/video_call_history_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/medication_confirmation_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/monthly_reports_screen.dart';
import 'screens/new_reminder_audio_screen.dart';
import 'screens/new_reminder_screen.dart';
import 'screens/postpone_confirmation_screen.dart';
import 'screens/recording_audio_screen.dart';
import 'screens/required_permissions_screen.dart';
import 'screens/medication_bulk_confirmation_screen.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/effectiveness_feedback_screen.dart';
import 'services/prescription_parser_service.dart';
import 'screens/register_elderly_screen.dart';
import 'screens/registration_success_screen.dart';
import 'screens/supervisor_dashboard_screen.dart';
import 'screens/supervisor_help_screen.dart';
import 'screens/supervisor_edit_elderly_profile_screen.dart';
import 'screens/supervisor_login_screen.dart';
import 'screens/supervisor_register_screen.dart';
import 'screens/supervisor_reminder_detail_screen.dart';
import 'screens/supervisor_settings_screen.dart';
import 'screens/take_photo_confirmation_screen.dart';
import 'screens/voice_settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/lembrete_service.dart';
import 'services/message_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/session_role_service.dart';
import 'services/crashlytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/video_call_service.dart';
import 'services/tts_service.dart';
import 'services/always_listening_service.dart';
import 'services/voice_notification_service.dart';
import 'services/widget_service.dart';
import 'services/analytics_service.dart';
import 'services/remote_config_service.dart';
import 'services/alarm_service.dart';
import 'di/injection.dart';

import 'theme/app_theme.dart';
import 'widgets/index.dart';
import 'widgets/app_status_banner.dart';
import 'services/app_status_service.dart';
import 'services/app_permission_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _RouteTracker _routeTracker = _RouteTracker();
Uri? _pendingWidgetUri;
bool _reminderNotificationActionInProgress = false;
const String _lastNotificationLaunchKey = 'last_notification_launch_key';
const String _lastNotificationLaunchAtKey = 'last_notification_launch_at';

Future<bool> _consumeNotificationLaunch(
  String payload,
  String? actionId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final fingerprint = '$payload|${actionId ?? ''}';
  final previous = prefs.getString(_lastNotificationLaunchKey);
  final previousAt = prefs.getInt(_lastNotificationLaunchAtKey) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (previous == fingerprint && now - previousAt < 2 * 60 * 1000) {
    return false;
  }
  await prefs.setString(_lastNotificationLaunchKey, fingerprint);
  await prefs.setInt(_lastNotificationLaunchAtKey, now);
  return true;
}

void _openWidgetUri(Uri? uri) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    _pendingWidgetUri = uri;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingWidgetUri;
      _pendingWidgetUri = null;
      _openWidgetUri(pending);
    });
    return;
  }

  final role = uri?.queryParameters['role'];
  if (role == 'supervisor' || SessionRoleService.isSupervisor) {
    navigator.pushNamed('/supervisor-dashboard');
    return;
  }

  final reminderId = uri?.queryParameters['id'];
  if (reminderId != null && reminderId.isNotEmpty) {
    navigator.pushNamed('/active-reminder', arguments: reminderId);
  } else {
    navigator.pushNamed('/elderly-home');
  }
}



bool isElderlyOnlyRoute(String routeName) {
  const elderlyRoutes = {
    '/elderly-onboarding',
    '/elderly-home',
    '/elderly-pairing',
    '/elderly-help',
    '/all-reminders',
    '/active-reminder',
    '/meal-detail',
    '/exercise-detail',
    '/reminder-detail',
    '/reinforcement-alert',
    '/medication-confirmation',
    '/take-photo-confirmation',
    '/elderly-profile',
    '/edit-profile',
    '/recording-audio',
    '/voice-settings',
    '/incoming-video-call',
  };

  return elderlyRoutes.contains(routeName);
}

bool isSupervisorProtectedRoute(String routeName) {
  const supervisorRoutes = {
    '/supervisor-dashboard',
    '/supervisor-settings',
    '/supervisor-help',
    '/supervisor-edit-elderly-profile',
    '/effectiveness-feedback',
    '/register-elderly',
    '/detailed-history',
    '/monthly-reports',
    '/activity-history',
    '/new-reminder',
    '/new-reminder-audio',
    '/identify-medication',
    '/medication-bulk-confirmation',
    '/barcode-scanner',
    '/supervisor-reminder-detail',
  };

  return supervisorRoutes.contains(routeName);
}

bool hasSupervisorAuthSession() {
  try {
    return Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance.currentUser != null;
  } catch (e) {
    debugPrint('Erro ao verificar sessao de auth: $e');
    return false;
  }
}

class _RouteTracker extends NavigatorObserver {
  String? currentRouteName;

  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    currentRouteName = name;
    if (name != null && name != '/') {
      try {
        getIt<AnalyticsService>().logScreenView(screenName: name);
      } catch (_) {}
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  AlarmService.instance.init();
  Uri? initialWidgetUri;
  if (!kIsWeb) {
    try {
      initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('Erro ao ler abertura inicial do widget: $e');
    }
  }
  configureDependencies();
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDUwOKQDK_Ub03pjJbhkMErpQciKoA0dJE',
          authDomain: 'lembreteamigo-26fd0.firebaseapp.com',
          projectId: 'lembreteamigo-26fd0',
          storageBucket: 'lembreteamigo-26fd0.firebasestorage.app',
          messagingSenderId: '591702637162',
          appId: '1:591702637162:web:6dc9980a749fea2d6d2813',
          measurementId: 'G-53ZH61QRE0',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('Firebase inicializado com sucesso.');
    await CrashlyticsService.instance.init();
  } catch (e) {
    debugPrint(
      'Erro ao inicializar Firebase. Operando em modo de simulacao local: $e',
    );
  }
  await SessionRoleService.load();
  try {
    await TTSService.instance.init();
  } catch (e) {
    debugPrint('Erro ao inicializar TTS. Continuando sem voz: $e');
  }

  try {
    await AlwaysListeningService.instance.initialize();
  } catch (e) {
    debugPrint('Erro ao inicializar AlwaysListeningService: $e');
  }

  try {
    await getIt<RemoteConfigService>().init();
  } catch (e) {
    debugPrint('Erro ao inicializar RemoteConfig: $e');
  }

  String? pendingPayload;
  String? pendingNotificationAction;
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init(navigatorKey);
      NotificationService.instance.onNotificationTapped = (lembreteId) {
        try {
          final lembrete = LembreteService.instance.lembretes
              .where((l) => l.id == lembreteId)
              .firstOrNull;
          if (lembrete != null && lembrete.titulo.isNotEmpty) {
            VoiceNotificationService.instance.speakTitle(
              lembrete.titulo,
              categoria: lembrete.categoria,
            );
          }
        } catch (_) {}
      };
      // onReminderAction foi removido na migração para o pacote alarm
      NotificationService.instance.onMessageAction =
          (messageId, actionId) async {
            await MessageService.instance.load();
            if (actionId == NotificationService.messageReadAction) {
              await MessageService.instance.markRead(messageId);
            }
          };
      NotificationService.instance.onIncomingCallAction =
          (callId, roomName, callType, actionId) async {
            if (actionId == NotificationService.callDeclineAction) {
              await VideoCallService.instance.declineCall(callId);
              return;
            }
            if (actionId == NotificationService.callAcceptAction) {
              await VideoCallService.instance.acceptCall(callId);
              await VideoCallService.instance.joinCall(
                roomName,
                callType: callType,
                callId: callId,
                alreadyVerified: true,
              );
              return;
            }
            navigatorKey.currentState?.pushNamed(
              '/incoming-video-call',
              arguments: {
                'callId': callId,
                'roomName': roomName,
                'callType': callType,
              },
            );
          };
      final launchDetails = await NotificationService.instance
          .getLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        final response = launchDetails.notificationResponse!;
        final payload = response.payload!;
        if (await _consumeNotificationLaunch(payload, response.actionId)) {
          pendingPayload = payload;
          pendingNotificationAction = response.actionId;
        }
      }
    } catch (e) {
      debugPrint(
        'Erro ao inicializar notificacoes. Continuando sem alarmes locais: $e',
      );
      AppStatusService.instance.report(
        id: 'local-notifications',
        title: 'Alarmes locais indisponiveis',
        message:
            'Verifique as permissoes de notificacao para nao perder lembretes.',
        severity: AppStatusSeverity.critical,
      );
    }
    try {
      final push = PushNotificationService.instance;

      push.onVideoCallReceived = (callId, roomName, callType) {
        final currentRoute = _routeTracker.currentRouteName;
        if (currentRoute == '/incoming-video-call' ||
            MeuApp.isIncomingCallScreenPushing ||
            VideoCallService.instance.activeCallNotifier.value != null) {
          return;
        }
        MeuApp.isIncomingCallScreenPushing = true;
        navigatorKey.currentState
            ?.pushNamed(
              '/incoming-video-call',
              arguments: {
                'callId': callId,
                'roomName': roomName,
                'callType': callType,
              },
            )
            .then((_) {
              MeuApp.isIncomingCallScreenPushing = false;
            });
      };

      push.onVideoCallOpenedApp = (callId, roomName, callType) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/incoming-video-call',
          (route) => false,
          arguments: {
            'callId': callId,
            'roomName': roomName,
            'callType': callType,
          },
        );
      };

      push.onAppMessageOpened = (messageId) {
        final navigator = navigatorKey.currentState;
        if (navigator == null) {
          pendingPayload = NotificationService.appMessagePayload(messageId);
          return;
        }
        navigator.pushNamed('/messages');
      };

      await push.init();
    } catch (e) {
      debugPrint(
        'Erro ao inicializar push notifications. Continuando sem FCM: $e',
      );
    }
  }

  if (!kIsWeb) {
    try {
      HomeWidget.widgetClicked.listen(_openWidgetUri);
    } catch (e) {
      debugPrint('Erro ao escutar widget clicks: $e');
    }
  }

  runApp(
    MeuApp(
      pendingPayload: pendingPayload,
      pendingNotificationAction: pendingNotificationAction,
    ),
  );
  if (initialWidgetUri != null) {
    _pendingWidgetUri = initialWidgetUri;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingWidgetUri;
      _pendingWidgetUri = null;
      _openWidgetUri(pending);
    });
  }
}

class MeuApp extends StatefulWidget {
  final String? pendingPayload;
  final String? pendingNotificationAction;
  const MeuApp({
    super.key,
    this.pendingPayload,
    this.pendingNotificationAction,
  });

  static bool isIncomingCallScreenPushing = false;

  @override
  State<MeuApp> createState() => _MeuAppState();
}

class _MeuAppState extends State<MeuApp> with WidgetsBindingObserver {
  final Set<String> _openedReminderKeys = {};
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  StreamSubscription<User?>? _authStateSubscription;
  bool _largeText = false;
  bool _highContrast = false;
  bool _slowVoice = false;
  bool _largeButtons = false;
  bool _reduceAnimations = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _incomingCallFirestoreSubscription;
  String? _lastListenedIdosoId;
  String? _lastListenedSupervisorId;
  Timer? _listenerRefreshTimer;

  @override
  void initState() {
    super.initState();
    _reminderNotificationActionInProgress = false;
    WidgetsBinding.instance.addObserver(this);
    unawaited(OfflineSyncService.instance.startAutoSync());
    _loadAccessibilityPreferences();
    LembreteService.instance.carregar().then((_) {
      _openDueReminderIfNeeded();
      _startIncomingCallFirestoreListener();
    });
    LembreteService.instance.notifier.addListener(_openDueReminderIfNeeded);
    try {
      if (Firebase.apps.isNotEmpty) {
        _authStateSubscription = FirebaseAuth.instance
            .authStateChanges()
            .listen(
              (user) async {
                if (user == null) {
                  if (SessionRoleService.isSupervisor ||
                      SessionRoleService.isElderly) {
                    await SessionRoleService.logout();
                    navigatorKey.currentState?.pushNamedAndRemoveUntil(
                      '/welcome',
                      (route) => false,
                    );
                  }
                }
                _startIncomingCallFirestoreListener();
              },
              onError: (e) {
                debugPrint('Erro no auth state listener: $e');
              },
            );
      }
    } catch (e) {
      debugPrint('Erro ao configurar auth listener: $e');
    }

    _listenerRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _startIncomingCallFirestoreListener();
    });
  }

  void _startIncomingCallFirestoreListener() async {
    if (Firebase.apps.isEmpty) return;

    if (SessionRoleService.isElderly &&
        !await SessionRoleService.canSyncElderlyPrivateData()) {
      await _incomingCallFirestoreSubscription?.cancel();
      _incomingCallFirestoreSubscription = null;
      _lastListenedIdosoId = null;
      _lastListenedSupervisorId = null;
      return;
    }

    final idosoId = await SessionRoleService.getActiveIdosoId();
    final supervisorId = SessionRoleService.isSupervisor
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : '';

    if (idosoId == _lastListenedIdosoId &&
        supervisorId == _lastListenedSupervisorId &&
        _incomingCallFirestoreSubscription != null) {
      return;
    }

    _lastListenedIdosoId = idosoId;
    _lastListenedSupervisorId = supervisorId;

    await _incomingCallFirestoreSubscription?.cancel();
    _incomingCallFirestoreSubscription = null;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'video_calls',
    );

    if (SessionRoleService.isSupervisor && supervisorId.isNotEmpty) {
      query = query.where('supervisorId', isEqualTo: supervisorId);
    } else if (SessionRoleService.isElderly &&
        !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
      query = query.where('idosoId', isEqualTo: idosoId);
    } else {
      return;
    }

    query = query.where('status', isEqualTo: 'ringing');

    _incomingCallFirestoreSubscription = query.snapshots().listen(
      (snapshot) {
        final docs = snapshot.docs.where((doc) {
          final initiatedBy =
              doc.data()['initiatedBy'] as String? ?? 'supervisor';
          if (SessionRoleService.isSupervisor) {
            return initiatedBy != 'supervisor';
          }
          return initiatedBy == 'supervisor';
        }).toList();

        if (docs.isNotEmpty) {
          final doc = docs.first;
          final data = doc.data();

          // Ignore old ringing calls (created more than 2 minutes ago)
          final startedAtObj = data['startedAt'];
          DateTime? startedAt;
          if (startedAtObj is Timestamp) {
            startedAt = startedAtObj.toDate();
          } else if (startedAtObj is String) {
            startedAt = DateTime.tryParse(startedAtObj);
          }
          if (startedAt != null) {
            final age = DateTime.now().difference(startedAt);
            if (age.inMinutes > 2) {
              return;
            }
          }

          final callId = doc.id;
          final roomName = data['roomName'] as String? ?? '';
          final callType = data['callType'] as String? ?? 'video';

          final currentRoute = _routeTracker.currentRouteName;
          if (currentRoute == '/incoming-video-call' ||
              MeuApp.isIncomingCallScreenPushing ||
              VideoCallService.instance.activeCallNotifier.value != null) {
            return;
          }

          MeuApp.isIncomingCallScreenPushing = true;
          navigatorKey.currentState
              ?.pushNamed(
                '/incoming-video-call',
                arguments: {
                  'callId': callId,
                  'roomName': roomName,
                  'callType': callType,
                },
              )
              .then((_) {
                MeuApp.isIncomingCallScreenPushing = false;
              });
        }
      },
      onError: (Object error) {
        if (error is! FirebaseException || error.code != 'permission-denied') {
          debugPrint('Não foi possível acompanhar chamadas recebidas.');
        }
        unawaited(_incomingCallFirestoreSubscription?.cancel());
        _incomingCallFirestoreSubscription = null;
        _lastListenedIdosoId = null;
        _lastListenedSupervisorId = null;
      },
    );
  }

  Future<void> _loadAccessibilityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lText = prefs.getBool('accessibility_large_text') ?? false;
    final hContrast = prefs.getBool('accessibility_high_contrast') ?? false;
    final sVoice = prefs.getBool('accessibility_slow_voice') ?? false;
    final lButtons = prefs.getBool('accessibility_large_buttons') ?? false;
    final rAnims = prefs.getBool('accessibility_reduce_animations') ?? false;

    if (_largeText != lText ||
        _highContrast != hContrast ||
        _slowVoice != sVoice ||
        _largeButtons != lButtons ||
        _reduceAnimations != rAnims) {
      setState(() {
        _largeText = lText;
        _highContrast = hContrast;
        _slowVoice = sVoice;
        _largeButtons = lButtons;
        _reduceAnimations = rAnims;
      });
      await TTSService.instance.setSpeechRate(_slowVoice ? 0.38 : 0.5);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      AlwaysListeningService.instance.resumeIfEnabled();
      LembreteService.instance.resumeSubscriptions();
      _loadAccessibilityPreferences();
      LembreteService.instance.carregar().then((_) {
        OfflineSyncService.instance.syncPendingWrites();
        WidgetService.instance.atualizar();
        _openDueReminderIfNeeded();
        _startIncomingCallFirestoreListener();
        _enforceElderlyAuth();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AlwaysListeningService.instance.pauseTemporarily();
      LembreteService.instance.pauseSubscriptions();
    }
  }

  void _enforceElderlyAuth() async {
    if (Firebase.apps.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null &&
        SessionRoleService.isElderly) {
      await SessionRoleService.logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/welcome',
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _listenerRefreshTimer?.cancel();
    _incomingCallFirestoreSubscription?.cancel();
    OfflineSyncService.instance.stopAutoSync();
    LembreteService.instance.notifier.removeListener(_openDueReminderIfNeeded);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openDueReminderIfNeeded() {
    if (_reminderNotificationActionInProgress) return;
    if (_lifecycleState != AppLifecycleState.resumed) return;
    if (SessionRoleService.isSupervisor) return;

    final currentRoute = _routeTracker.currentRouteName;
    if (currentRoute == '/active-reminder' ||
        currentRoute == '/take-photo-confirmation' ||
        currentRoute == '/medication-confirmation' ||
        currentRoute == '/reinforcement-alert') {
      return;
    }

    final reminder = _findDueReminder();
    if (reminder == null) return;

    final key = _reminderOpenKey(reminder, DateTime.now());
    if (_openedReminderKeys.contains(key)) return;
    _openedReminderKeys.add(key);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      final latestRoute = _routeTracker.currentRouteName;
      if (navigator == null ||
          latestRoute == '/active-reminder' ||
          latestRoute == '/take-photo-confirmation' ||
          latestRoute == '/medication-confirmation' ||
          latestRoute == '/reinforcement-alert') {
        return;
      }
      navigator.pushNamed('/active-reminder', arguments: reminder.id);
    });
  }

  Lembrete? _findDueReminder() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final candidates =
        LembreteService.instance.lembretes.where((lembrete) {
          if (lembrete.concluido) return false;
          if (lembrete.status == LembreteStatus.perdido ||
              lembrete.status == LembreteStatus.precisaDeAjuda) {
            return false;
          }
          if (!_isReminderActiveToday(lembrete, now)) {
            return false;
          }

          final reminderMinutes =
              lembrete.horarioHour * 60 + lembrete.horarioMinute;
          if (lembrete.recorrenciaIntervalo ||
              lembrete.recorrencia == 'intervalo') {
            final interval = _safeIntervalHours(lembrete);
            final diff = nowMinutes - reminderMinutes;
            return diff >= 0 && diff % (interval * 60) <= 1;
          }
          final diff = nowMinutes - reminderMinutes;
          return diff >= 0 && diff <= 1;
        }).toList()..sort((a, b) {
          final aMinutes = a.horarioHour * 60 + a.horarioMinute;
          final bMinutes = b.horarioHour * 60 + b.horarioMinute;
          return aMinutes.compareTo(bMinutes);
        });

    return candidates.isEmpty ? null : candidates.first;
  }

  bool _isReminderActiveToday(Lembrete lembrete, DateTime now) =>
      Lembrete.isReminderActiveOn(lembrete, now);

  String _reminderOpenKey(Lembrete lembrete, DateTime now) {
    final date = '${now.year}-${now.month}-${now.day}';
    final nowMinutes = now.hour * 60 + now.minute;
    final reminderMinutes = lembrete.horarioHour * 60 + lembrete.horarioMinute;
    var occurrenceMinutes = reminderMinutes;
    if (lembrete.recorrenciaIntervalo || lembrete.recorrencia == 'intervalo') {
      final intervalMinutes = _safeIntervalHours(lembrete) * 60;
      final diff = nowMinutes - reminderMinutes;
      if (diff >= 0) {
        occurrenceMinutes =
            reminderMinutes + (diff ~/ intervalMinutes) * intervalMinutes;
      }
    }
    return '$date:${lembrete.id}:$occurrenceMinutes';
  }

  int _safeIntervalHours(Lembrete lembrete) {
    final interval = lembrete.intervaloHoras ?? 4;
    if (interval < 1) return 1;
    if (interval > 24) return 24;
    return interval;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lembrete Amigo',
      navigatorKey: navigatorKey,
      navigatorObservers: [_routeTracker],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: _largeButtons
                ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: _largeButtons
                ? const Size(64, 64)
                : const Size(48, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: _largeButtons
                ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: _largeButtons
                ? const Size(64, 64)
                : const Size(48, 48),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: _largeButtons
                ? const EdgeInsets.symmetric(horizontal: 24, vertical: 18)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: _largeButtons
                ? const Size(64, 48)
                : const Size(48, 36),
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final systemScale = mediaQuery.textScaler.scale(1.0);
        final scaleFactor = systemScale * (_largeText ? 1.15 : 1.0);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scaleFactor.clamp(1.0, 2.5)),
          ),
          child: AppStatusBanner(child: child ?? const SizedBox.shrink()),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        final routeName = settings.name ?? '/';
        if (isSupervisorProtectedRoute(routeName) &&
            (!hasSupervisorAuthSession() || !SessionRoleService.isSupervisor)) {
          return MaterialPageRoute(
            builder: (_) => const SupervisorLoginScreen(),
            settings: const RouteSettings(name: '/supervisor-login'),
          );
        }
        if (isElderlyOnlyRoute(routeName) && SessionRoleService.isSupervisor) {
          return MaterialPageRoute(
            builder: (_) => const SupervisorDashboardScreen(),
            settings: const RouteSettings(name: '/supervisor-dashboard'),
          );
        }
        switch (settings.name) {
          case '/':
            page = _AppStartup(
              pendingPayload: widget.pendingPayload,
              pendingNotificationAction: widget.pendingNotificationAction,
            );
            break;
          case '/required-permissions':
            page = const RequiredPermissionsScreen();
            break;
          case '/elderly-onboarding':
            page = const ElderlyOnboardingScreen();
            break;
          case '/elderly-home':
            final elderlyHomeArgs = settings.arguments;
            final elderlyHomeMap = elderlyHomeArgs is Map<String, dynamic>
                ? elderlyHomeArgs
                : null;
            final connected = elderlyHomeMap?['connected'] as bool? ?? false;
            final speak = elderlyHomeMap?['speak'] as String?;
            page = ElderlyHomeScreen(
              showConnected: connected,
              speakText: speak,
            );
            break;
          case '/elderly-pairing':
            page = const ElderlyPairingScreen();
            break;
          case '/elderly-help':
            page = const ElderlyHelpScreen();
            break;
          case '/messages':
            page = const MessagesScreen();
            break;
          case '/all-reminders':
            page = const AllRemindersScreen();
            break;
          case '/active-reminder':
            page = const ActiveReminderScreen();
            break;
          case '/reminder-detail':
          case '/meal-detail':
          case '/exercise-detail':
            page = const ReminderDetailScreen();
            break;
          case '/reinforcement-alert':
            page = const PostponeConfirmationScreen();
            break;
          case '/supervisor-reminder-detail':
            final args = settings.arguments;
            if (args is Map<String, dynamic> &&
                args['title'] is String &&
                args['time'] is String &&
                args['iconData'] is IconData &&
                args['accentColor'] is Color &&
                args['category'] is String) {
              page = SupervisorReminderDetailScreen(
                title: args['title'] as String,
                time: args['time'] as String,
                iconData: args['iconData'] as IconData,
                accentColor: args['accentColor'] as Color,
                category: args['category'] as String,
                lembrete: args['lembrete'] as Lembrete?,
              );
            } else {
              page = const SupervisorDashboardScreen();
            }
            break;
          case '/medication-confirmation':
            page = const MedicationConfirmationScreen();
            break;
          case '/take-photo-confirmation':
            page = const TakePhotoConfirmationScreen();
            break;
          case '/elderly-profile':
            page = const ElderlyProfileScreen();
            break;
          case '/edit-profile':
            page = const EditProfileScreen();
            break;
          case '/new-reminder':
            final args = settings.arguments;
            final reminder = args is Lembrete ? args : null;
            page = NewReminderScreen(lembrete: reminder);
            break;
          case '/new-reminder-audio':
            page = const NewReminderAudioScreen();
            break;
          case '/recording-audio':
            page = const RecordingAudioScreen();
            break;
          case '/supervisor-login':
            page = const SupervisorLoginScreen();
            break;
          case '/supervisor-dashboard':
            page = const SupervisorDashboardScreen();
            break;
          case '/supervisor-register':
            page = const SupervisorRegisterScreen();
            break;
          case '/registration-success':
            page = const RegistrationSuccessScreen();
            break;
          case '/supervisor-settings':
            page = const SupervisorSettingsScreen();
            break;

          case '/supervisor-help':
            page = const SupervisorHelpScreen();
            break;
          case '/supervisor-edit-elderly-profile':
            page = const SupervisorEditElderlyProfileScreen();
            break;
          case '/register-elderly':
            page = const RegisterElderlyScreen();
            break;
          case '/detailed-history':
            page = const ActivityHistoryScreen();
            break;
          case '/monthly-reports':
            page = const MonthlyReportsScreen();
            break;
          case '/activity-history':
            page = const ActivityHistoryScreen();
            break;
          case '/forgot-password':
            page = const ForgotPasswordScreen();
            break;
          case '/emergency-alert':
            final emergencyArgs = settings.arguments;
            final emergencyMap = emergencyArgs is Map<String, dynamic>
                ? emergencyArgs
                : null;
            page = EmergencyAlertScreen(
              lembrete: emergencyMap?['lembrete'] as Lembrete?,
              totalAlertas: emergencyMap?['totalAlertas'] as int? ?? 0,
            );
            break;
          case '/incoming-video-call':
            final incomingCallArgs = settings.arguments;
            final incomingCallMap = incomingCallArgs is Map<String, dynamic>
                ? incomingCallArgs
                : null;
            page = IncomingVideoCallScreen(
              callId: incomingCallMap?['callId'] as String? ?? '',
              roomName: incomingCallMap?['roomName'] as String? ?? '',
              callType: incomingCallMap?['callType'] as String? ?? 'video',
            );
            break;
          case '/post-call-summary':
            final postCallArgs = settings.arguments;
            final postCallMap = postCallArgs is Map<String, dynamic>
                ? postCallArgs
                : null;
            page = PostCallSummaryScreen(
              callerName: postCallMap?['callerName'] as String? ?? '',
              callType: postCallMap?['callType'] as String? ?? 'video',
              durationSeconds:
                  (postCallMap?['durationSeconds'] as num?)?.toInt() ?? 0,
              status:
                  postCallMap?['status'] as VideoCallStatus? ??
                  VideoCallStatus.ended,
            );
            break;
          case '/video-call-history':
            page = const VideoCallHistoryScreen();
            break;
          case '/welcome':
            page = const WelcomeScreen();
            break;
          case '/voice-settings':
            page = const VoiceSettingsScreen();
            break;
          case '/identify-medication':
            page = const IdentifyMedicationScreen();
            break;
          case '/medication-bulk-confirmation':
            final medicationBulkArgs = settings.arguments;
            final items = medicationBulkArgs is List<PrescriptionReminderItem>
                ? medicationBulkArgs
                : <PrescriptionReminderItem>[];
            page = MedicationBulkConfirmationScreen(initialItems: items);
            break;
          case '/barcode-scanner':
            page = const BarcodeScannerScreen();
            break;
          case '/effectiveness-feedback':
            page = const EffectivenessFeedbackScreen();
            break;

          default:
            page = const WelcomeScreen();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}

class _AppStartup extends StatefulWidget {
  final String? pendingPayload;
  final String? pendingNotificationAction;
  const _AppStartup({this.pendingPayload, this.pendingNotificationAction});

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SessionRoleService.load();
      if (!mounted) return;

      if (await _openPendingReminderIfAvailable()) {
        return;
      }

      await _continueStartup();
    });
  }

  Future<bool> _openPendingReminderIfAvailable() async {
    final pendingPayload = widget.pendingPayload;
    if (pendingPayload == null || pendingPayload.isEmpty) return false;

    final call = NotificationService.decodeIncomingCallPayload(pendingPayload);
    if (call != null) {
      final callId = call['callId']!;
      final roomName = call['roomName']!;
      final callType = call['callType']!;
      if (widget.pendingNotificationAction ==
          NotificationService.callDeclineAction) {
        await VideoCallService.instance.declineCall(callId);
        return false;
      }
      if (widget.pendingNotificationAction ==
          NotificationService.callAcceptAction) {
        await VideoCallService.instance.acceptCall(callId);
        await VideoCallService.instance.joinCall(
          roomName,
          callType: callType,
          callId: callId,
          alreadyVerified: true,
        );
        return true;
      }
      navigatorKey.currentState?.pushNamed(
        '/incoming-video-call',
        arguments: {
          'callId': callId,
          'roomName': roomName,
          'callType': callType,
        },
      );
      return true;
    }

    if (NotificationService.isAppMessagePayload(pendingPayload)) {
      if (widget.pendingNotificationAction ==
          NotificationService.messageReadAction) {
        final messageId = pendingPayload.substring('app_message:'.length);
        await MessageService.instance.load();
        await MessageService.instance.markRead(messageId);
        return false;
      }
      navigatorKey.currentState?.pushNamed('/messages');
      return true;
    }

    if (NotificationService.isMissedCallPayload(pendingPayload)) {
      navigatorKey.currentState?.pushNamed('/video-call-history');
      return true;
    }

    if (NotificationService.isSupervisorAlertPayload(pendingPayload)) {
      navigatorKey.currentState?.pushNamed('/supervisor-dashboard');
      return true;
    }

    try {
      await LembreteService.instance.carregar();
      _reminderNotificationActionInProgress = false;

      final lembrete = await LembreteService.instance.buscarPorId(
        pendingPayload,
      );
      if (!mounted || lembrete == null || lembrete.concluido) {
        return false;
      }


      navigatorKey.currentState?.pushNamed(
        '/active-reminder',
        arguments: lembrete,
      );
      return true;
    } catch (e) {
      _reminderNotificationActionInProgress = false;
      debugPrint('Payload de notificacao ignorado na inicializacao: $e');
      return false;
    }
  }

  Future<void> _continueStartup() async {
    if (!kIsWeb && !await AppPermissionService.instance.isGateCompleted()) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/required-permissions',
        (route) => false,
      );
      return;
    }

    WidgetService.instance.atualizar();

    if (SessionRoleService.isElderly) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await SessionRoleService.logout();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('paired_idoso_id', user.uid);
      final pairedIdosoId = prefs.getString('paired_idoso_id');
      if (pairedIdosoId != null) {
        final isPaired =
            await SessionRoleService.isElderlyConnectedToSupervisor();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/elderly-home',
          (route) => false,
          arguments: {'connected': isPaired},
        );
      } else {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/elderly-onboarding',
          (route) => false,
        );
      }
      return;
    } else if (SessionRoleService.isSupervisor) {
      if (hasSupervisorAuthSession()) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/supervisor-dashboard',
          (route) => false,
        );
      } else {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/supervisor-login',
          (route) => false,
        );
      }
      return;
    }

    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/welcome',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AlexAvatar(size: 120),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
