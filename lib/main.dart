import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/elderly_onboarding_screen.dart';
import 'screens/elderly_home_screen.dart';

import 'screens/elderly_home_screen_v2.dart';
import 'screens/elderly_help_screen.dart';
import 'screens/heart_rate_measure_screen.dart';
import 'screens/medication_list_screen.dart';
import 'screens/active_reminder_screen.dart';
import 'screens/medication_confirmation_screen.dart';
import 'screens/take_photo_confirmation_screen.dart';
import 'screens/reinforcement_alert_screen.dart';
import 'screens/reminder_with_audio_screen.dart';
import 'screens/elderly_profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/adjust_task_screen.dart';
import 'screens/new_reminder_screen.dart';
import 'screens/new_reminder_audio_screen.dart';
import 'screens/recording_audio_screen.dart';
import 'screens/audio_send_feedback_screen.dart';
import 'screens/audio_send_feedback_connected_screen.dart';
import 'screens/supervisor_login_screen.dart';
import 'screens/supervisor_dashboard_screen.dart';
import 'screens/supervisor_dashboard_connected_screen.dart';
import 'screens/supervisor_dashboard_empty_screen.dart';
import 'screens/supervisor_register_screen.dart';
import 'screens/registration_success_screen.dart';
import 'screens/supervisor_settings_screen.dart';
import 'screens/connected_settings_screen.dart';
import 'screens/register_elderly_screen.dart';
import 'screens/elderly_pairing_screen.dart';
import 'screens/detailed_history_screen.dart';
import 'screens/monthly_reports_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/emergency_alert_screen.dart';
import 'screens/no_connection_screen.dart';
import 'screens/all_reminders_screen.dart';
import 'screens/supervisor_help_screen.dart';
import 'screens/meals_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/water_screen.dart';
import 'screens/custom_reminders_screen.dart';
import 'screens/meal_detail_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/medication_reinforcement_screen.dart';
import 'screens/meal_reinforcement_screen.dart';
import 'screens/supervisor_reminder_detail_screen.dart';
import 'services/tts_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase inicializado com sucesso.');
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase. Operando em modo de simulação local: $e');
  }
  await TTSService.instance.init();
  await NotificationService.instance.init(navigatorKey);
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeuApp Lembretes',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const WelcomeScreen();
            break;
          case '/elderly-onboarding':
            page = const ElderlyOnboardingScreen();
            break;
          case '/elderly-home':
            final args = settings.arguments as Map<String, dynamic>?;
            final connected = args?['connected'] as bool? ?? false;
            page = ElderlyHomeScreen(showConnected: connected);
            break;
          case '/elderly-pairing':
            page = const ElderlyPairingScreen();
            break;
          case '/elderly-home-v2':
            page = const ElderlyHomeScreenV2();
            break;
          case '/elderly-help':
            page = const ElderlyHelpScreen();
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
          case '/medication-reinforcement':
            page = const MedicationReinforcementScreen();
            break;
          case '/meal-reinforcement':
            page = const MealReinforcementScreen();
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
          case '/reinforcement-alert':
            page = const ReinforcementAlertScreen();
            break;
          case '/reminder-with-audio':
            page = const ReminderWithAudioScreen();
            break;
          case '/elderly-profile':
            page = const ElderlyProfileScreen();
            break;
          case '/edit-profile':
            page = const EditProfileScreen();
            break;
          case '/adjust-task':
            page = const AdjustTaskScreen();
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
          case '/audio-send-feedback':
            page = const AudioSendFeedbackScreen();
            break;
          case '/audio-send-feedback-connected':
            page = const AudioSendFeedbackConnectedScreen();
            break;
          case '/supervisor-login':
            page = const SupervisorLoginScreen();
            break;
          case '/supervisor-dashboard':
            page = const SupervisorDashboardScreen();
            break;
          case '/supervisor-dashboard-connected':
            page = const SupervisorDashboardConnectedScreen();
            break;
          case '/supervisor-dashboard-empty':
            page = const SupervisorDashboardEmptyScreen();
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
          case '/connected-settings':
            page = const ConnectedSettingsScreen();
            break;
          case '/supervisor-help':
            page = const SupervisorHelpScreen();
            break;
          case '/register-elderly':
            page = const RegisterElderlyScreen();
            break;
          case '/detailed-history':
            page = const DetailedHistoryScreen();
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
          case '/no-connection':
            page = const NoConnectionScreen();
            break;
          case '/meals':
            page = const MealsScreen();
            break;
          case '/exercise':
            page = const ExerciseScreen();
            break;
          case '/water':
            page = const WaterScreen();
            break;
          case '/custom':
            page = const CustomRemindersScreen();
            break;
          default:
            page = const WelcomeScreen();
        }
        return MaterialPageRoute(builder: (_) => page);
      },
    );
  }
}
