import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lembretes_app/models/video_call.dart';
import 'package:lembretes_app/screens/elderly_onboarding_screen.dart';
import 'package:lembretes_app/screens/forgot_password_screen.dart';
import 'package:lembretes_app/screens/post_call_summary_screen.dart';
import 'package:lembretes_app/screens/registration_success_screen.dart';
import 'package:lembretes_app/screens/welcome_screen.dart';
import 'package:lembretes_app/theme/app_theme.dart';

void main() {
  const ttsChannel = MethodChannel('flutter_tts');

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'role': 'elderly',
      'user_role': 'elderly',
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpScreenForGolden(
    WidgetTester tester, {
    required Widget screen,
    Size size = const Size(390, 844), // iPhone / Android padrão
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Golden Tests - Captura de Telas (Screenshots)', () {
    testWidgets('Print Tela de Boas-vindas (WelcomeScreen)', (tester) async {
      await pumpScreenForGolden(
        tester,
        screen: const WelcomeScreen(),
      );

      await expectLater(
        find.byType(WelcomeScreen),
        matchesGoldenFile('goldens/welcome_screen.png'),
      );
    });

    testWidgets('Print Tela de Onboarding do Idoso (ElderlyOnboardingScreen)', (
      tester,
    ) async {
      await pumpScreenForGolden(
        tester,
        screen: const ElderlyOnboardingScreen(),
      );

      await expectLater(
        find.byType(ElderlyOnboardingScreen),
        matchesGoldenFile('goldens/elderly_onboarding_screen.png'),
      );
    });

    testWidgets('Print Tela de Sucesso de Cadastro (RegistrationSuccessScreen)', (
      tester,
    ) async {
      await pumpScreenForGolden(
        tester,
        screen: const RegistrationSuccessScreen(),
      );

      await expectLater(
        find.byType(RegistrationSuccessScreen),
        matchesGoldenFile('goldens/registration_success_screen.png'),
      );
    });

    testWidgets('Print Tela de Esqueci Minha Senha (ForgotPasswordScreen)', (
      tester,
    ) async {
      await pumpScreenForGolden(
        tester,
        screen: const ForgotPasswordScreen(),
      );

      await expectLater(
        find.byType(ForgotPasswordScreen),
        matchesGoldenFile('goldens/forgot_password_screen.png'),
      );
    });

    testWidgets('Print Resumo Pós-Chamada (PostCallSummaryScreen)', (
      tester,
    ) async {
      await pumpScreenForGolden(
        tester,
        screen: const PostCallSummaryScreen(
          callerName: 'Maria Silva (Cuidadora)',
          callType: 'video',
          durationSeconds: 185,
          status: VideoCallStatus.ended,
        ),
      );

      await expectLater(
        find.byType(PostCallSummaryScreen),
        matchesGoldenFile('goldens/post_call_summary_screen.png'),
      );
    });
  });
}
