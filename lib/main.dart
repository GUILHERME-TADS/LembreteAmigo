import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/lembrete.dart';
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
import 'screens/achievements_screen.dart';
import 'screens/identify_medication_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/incoming_video_call_screen.dart';
import 'screens/active_video_call_screen.dart';
import 'screens/video_call_history_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/heart_rate_measure_screen.dart';
import 'screens/meal_detail_screen.dart';
import 'screens/medication_confirmation_screen.dart';
import 'screens/medication_list_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/monthly_reports_screen.dart';
import 'screens/new_reminder_audio_screen.dart';
import 'screens/new_reminder_screen.dart';
import 'screens/postpone_confirmation_screen.dart';
import 'screens/recording_audio_screen.dart';
import 'screens/register_elderly_screen.dart';
import 'screens/registration_success_screen.dart';
import 'screens/supervisor_dashboard_screen.dart';
import 'screens/supervisor_help_screen.dart';
import 'screens/supervisor_login_screen.dart';
import 'screens/supervisor_register_screen.dart';
import 'screens/supervisor_reminder_detail_screen.dart';
import 'screens/supervisor_settings_screen.dart';
import 'screens/take_photo_confirmation_screen.dart';
import 'screens/voice_settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/lembrete_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/session_role_service.dart';
import 'services/crashlytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/tts_service.dart';
import 'services/widget_service.dart';
import 'services/achievement_service.dart';
import 'services/always_listening_service.dart';

import 'theme/app_theme.dart';
import 'widgets/index.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _RouteTracker _routeTracker = _RouteTracker();

bool isElderlyOnlyRoute(String routeName) {
  const elderlyRoutes = {
    '/elderly-onboarding',
    '/elderly-home',
    '/elderly-pairing',
    '/elderly-help',
    '/heart-rate',
    '/all-reminders',
    '/medication-list',
    '/active-reminder',
    '/meal-detail',
    '/exercise-detail',
    '/reinforcement-alert',
    '/medication-confirmation',
    '/take-photo-confirmation',
    '/elderly-profile',
    '/edit-profile',
    '/recording-audio',
    '/voice-settings',
    '/incoming-video-call',
    '/active-video-call',
    '/achievements',
  };

  return elderlyRoutes.contains(routeName);
}

bool isSupervisorProtectedRoute(String routeName) {
  const supervisorRoutes = {
    '/supervisor-dashboard',
    '/supervisor-settings',
    '/supervisor-help',
    '/register-elderly',
    '/detailed-history',
    '/monthly-reports',
    '/activity-history',
    '/new-reminder',
    '/new-reminder-audio',
    '/supervisor-reminder-detail',
  };

  return supervisorRoutes.contains(routeName);
}

bool hasSupervisorAuthSession() {
  try {
    if (Firebase.apps.isEmpty) {
      return true; // Bypass auth check in local simulation/dev mode
    }
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

class _RouteTracker extends NavigatorObserver {
  String? currentRouteName;

  void _track(Route<dynamic>? route) {
    currentRouteName = route?.settings.name;
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
  try {
    await Firebase.initializeApp();
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

  String? pendingPayload;
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init(navigatorKey);
      final launchDetails = await NotificationService.instance
          .getLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        pendingPayload = launchDetails.notificationResponse!.payload;
      }
    } catch (e) {
      debugPrint('Erro ao inicializar notificacoes. Continuando sem alarmes locais: $e');
    }
    try {
      final push = PushNotificationService.instance;
      await push.init();

      push.onVideoCallReceived = (callId, roomName) {
        final currentRoute = _routeTracker.currentRouteName;
        if (currentRoute == '/incoming-video-call' ||
            currentRoute == '/active-video-call') {
          return;
        }
        navigatorKey.currentState?.pushNamed(
          '/incoming-video-call',
          arguments: {'callId': callId, 'roomName': roomName},
        );
      };

      push.onVideoCallOpenedApp = (callId, roomName) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/incoming-video-call',
          (route) => false,
          arguments: {'callId': callId, 'roomName': roomName},
        );
      };
    } catch (e) {
      debugPrint('Erro ao inicializar push notifications. Continuando sem FCM: $e');
    }
    try {
      await AchievementService.instance.initialize();
      await AlwaysListeningService.instance.initialize();
    } catch (e) {
      debugPrint('Erro ao inicializar servicos: $e');
    }
  }

  if (!kIsWeb) {
    try {
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null && uri.toString().isNotEmpty) {
          final reminderId = uri.queryParameters['id'];
          if (reminderId != null && reminderId.isNotEmpty) {
            navigatorKey.currentState?.pushNamed(
              '/active-reminder',
              arguments: reminderId,
            );
          }
        } else {
          navigatorKey.currentState?.pushNamed('/elderly-home');
        }
      });
    } catch (_) {}
  }

  runApp(MeuApp(pendingPayload: pendingPayload));
}

class MeuApp extends StatefulWidget {
  final String? pendingPayload;
  const MeuApp({super.key, this.pendingPayload});

  @override
  State<MeuApp> createState() => _MeuAppState();
}

class _MeuAppState extends State<MeuApp> with WidgetsBindingObserver {
  Timer? _unlockedReminderTimer;
  final Set<String> _openedReminderKeys = {};
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  StreamSubscription<User?>? _authStateSubscription;
  bool _largeText = false;
  bool _highContrast = false;
  bool _slowVoice = false;
  bool _largeButtons = false;
  bool _reduceAnimations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(OfflineSyncService.instance.startAutoSync());
    _loadAccessibilityPreferences();
    LembreteService.instance.carregar().then((_) => _openDueReminderIfNeeded());
    LembreteService.instance.notifier.addListener(_openDueReminderIfNeeded);
    _unlockedReminderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadAccessibilityPreferences();
      LembreteService.instance.carregar().then((_) => _openDueReminderIfNeeded());
    });
    try {
      if (Firebase.apps.isNotEmpty) {
        _authStateSubscription =
            FirebaseAuth.instance.authStateChanges().listen((user) async {
          if (user == null && SessionRoleService.isSupervisor) {
            await SessionRoleService.logout();
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/supervisor-login',
              (route) => false,
            );
          }
        });
      }
    } catch (_) {}
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
      _loadAccessibilityPreferences();
      LembreteService.instance.carregar().then((_) {
        OfflineSyncService.instance.syncPendingWrites();
        WidgetService.instance.atualizar();
        _openDueReminderIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _unlockedReminderTimer?.cancel();
    OfflineSyncService.instance.stopAutoSync();
    LembreteService.instance.notifier.removeListener(_openDueReminderIfNeeded);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openDueReminderIfNeeded() {
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
          if (lembrete.status == LembreteStatus.perdido) return false;
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
      theme: (_highContrast ? AppTheme.highContrastTheme : AppTheme.lightTheme)
          .copyWith(
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
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        final routeName = settings.name ?? '/';
        if (isSupervisorProtectedRoute(routeName) &&
            (!hasSupervisorAuthSession() ||
                !SessionRoleService.isSupervisor)) {
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
            page = _AppStartup(pendingPayload: widget.pendingPayload);
            break;
          case '/elderly-onboarding':
            page = const ElderlyOnboardingScreen();
            break;
          case '/elderly-home':
            final args = settings.arguments as Map<String, dynamic>?;
            final connected = args?['connected'] as bool? ?? false;
            final speak = args?['speak'] as String?;
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
          case '/heart-rate':
            page = const HeartRateMeasureScreen();
            break;
          case '/all-reminders':
            page = const AllRemindersScreen();
            break;
          case '/medication-list':
            page = const MedicationListScreen();
            break;
          case '/active-reminder':
            page = const ActiveReminderScreen();
            break;
          case '/meal-detail':
            page = const MealDetailScreen();
            break;
          case '/exercise-detail':
            page = const ExerciseDetailScreen();
            break;
          case '/reinforcement-alert':
            page = const PostponeConfirmationScreen();
            break;
          case '/supervisor-reminder-detail':
            final args = settings.arguments as Map<String, dynamic>;
            page = SupervisorReminderDetailScreen(
              title: args['title'] as String,
              time: args['time'] as String,
              iconData: args['iconData'] as IconData,
              accentColor: args['accentColor'] as Color,
              category: args['category'] as String,
            );
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
            page = const NewReminderScreen();
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
            page = const EmergencyAlertScreen();
            break;
          case '/incoming-video-call':
            final args = settings.arguments as Map<String, dynamic>?;
            page = IncomingVideoCallScreen(
              callId: args?['callId'] as String? ?? '',
              roomName: args?['roomName'] as String? ?? '',
            );
            break;
          case '/active-video-call':
            final args = settings.arguments as Map<String, dynamic>?;
            page = ActiveVideoCallScreen(
              callId: args?['callId'] as String? ?? '',
              roomName: args?['roomName'] as String? ?? '',
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
          case '/achievements':
            page = const AchievementsScreen();
            break;
          case '/identify-medication':
            page = const IdentifyMedicationScreen();
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
  const _AppStartup({this.pendingPayload});

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.pendingPayload != null) {
        navigatorKey.currentState?.pushNamed(
          '/active-reminder',
          arguments: widget.pendingPayload,
        );
        return;
      }

      await SessionRoleService.load();
      if (!mounted) return;

      WidgetService.instance.atualizar();

      if (SessionRoleService.isElderly) {
        final prefs = await SharedPreferences.getInstance();
        final pairedIdosoId = prefs.getString('paired_idoso_id');
        if (pairedIdosoId != null) {
          final isPaired = pairedIdosoId != 'idoso_autonomo';
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
    });
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
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
