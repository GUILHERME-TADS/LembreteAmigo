import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/video_call.dart';
import 'package:lembretes_app/screens/elderly_onboarding_screen.dart';
import 'package:lembretes_app/screens/new_reminder_audio_screen.dart';
import 'package:lembretes_app/screens/post_call_summary_screen.dart';
import 'package:lembretes_app/screens/registration_success_screen.dart';
import 'package:lembretes_app/widgets/responsive_layout.dart';

void main() {
  Future<void> pumpAtSize(
    WidgetTester tester, {
    required Size size,
    required Widget screen,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: screen,
      ),
    );
    await tester.pump();
  }

  testWidgets('limits the app viewport on wide displays', (tester) async {
    double? observedWidth;

    await pumpAtSize(
      tester,
      size: const Size(1800, 900),
      screen: ResponsiveAppViewport(
        child: Builder(
          builder: (context) {
            observedWidth = MediaQuery.sizeOf(context).width;
            return const ColoredBox(color: Colors.white);
          },
        ),
      ),
    );

    expect(observedWidth, AppBreakpoints.expanded);
    expect(tester.takeException(), isNull);
  });

  testWidgets('success screen scrolls on a small device with large text', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 480),
      textScale: 2.5,
      screen: const RegistrationSuccessScreen(),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Tudo pronto!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.text('Ir para o Painel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post-call screen scrolls in landscape with large text', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      size: const Size(640, 360),
      textScale: 2,
      screen: const PostCallSummaryScreen(
        callerName: 'Contato com nome longo para teste',
        callType: 'video',
        durationSeconds: 125,
        status: VideoCallStatus.ended,
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Contato com nome longo para teste'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding scrolls on a small device with large text', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 480),
      textScale: 2.5,
      screen: const ElderlyOnboardingScreen(),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('audio reminder scrolls on a small device with large text', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 480),
      textScale: 2.5,
      screen: const NewReminderAudioScreen(),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Toque para começar a gravar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('scroll helper fills a tablet and accepts long content', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      size: const Size(1024, 768),
      screen: const Scaffold(
        body: ResponsiveScrollView(
          maxContentWidth: 720,
          child: Column(children: [SizedBox(height: 900), Text('fim')]),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
