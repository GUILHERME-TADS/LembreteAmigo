import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/tts_service.dart';
import 'package:lembretes_app/widgets/alex_avatar.dart';
import 'package:lembretes_app/widgets/alex_floating_help_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  late List<MethodCall> ttsCalls;

  setUp(() async {
    ttsCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
          ttsCalls.add(call);
          return 1;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    await TTSService.instance.parar();
    ttsCalls.clear();
  });

  tearDown(() async {
    await TTSService.instance.parar();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('o texto ME EXPLICA inicia e interrompe a fala', (tester) async {
    var callbackFinished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: AlexFloatingHelpButton(
            textoExplicacao: 'Explicação de teste.',
            onTapped: () async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              callbackFinished = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('ME EXPLICA')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(callbackFinished, isTrue);
    expect(
      ttsCalls.any((call) {
        if (call.method != 'speak') return false;
        final arguments = call.arguments;
        if (arguments is String) return arguments == 'Explicação de teste.';
        return arguments is Map && arguments['text'] == 'Explicação de teste.';
      }),
      isTrue,
    );
    expect(find.text('PARAR DE FALAR'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('PARAR DE FALAR')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('ME EXPLICA'), findsOneWidget);
    expect(
      ttsCalls.where((call) => call.method == 'stop').length,
      greaterThan(1),
    );
  });

  testWidgets('o arraste mantém o Alex dentro da área segura', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: AlexFloatingHelpButton(
            textoExplicacao: 'Explicação de teste.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatarFinder = find.byType(AlexAvatar);
    final hitAreaFinder = find.byKey(
      const ValueKey<String>('alex-help-button-hit-area'),
    );
    final initialRect = tester.getRect(avatarFinder);

    await tester.drag(hitAreaFinder, const Offset(-1000, -1000));
    await tester.pump();

    final topLeftRect = tester.getRect(avatarFinder);
    expect(topLeftRect.left, greaterThanOrEqualTo(11.5));
    expect(topLeftRect.top, greaterThanOrEqualTo(11.5));
    expect(topLeftRect.center.dx, lessThan(initialRect.center.dx));
    expect(topLeftRect.center.dy, lessThan(initialRect.center.dy));

    final bubbleRect = tester.getRect(find.text('ME EXPLICA'));
    expect(bubbleRect.left, greaterThanOrEqualTo(0));
    expect(bubbleRect.right, lessThanOrEqualTo(360));

    await tester.drag(hitAreaFinder, const Offset(1000, 1000));
    await tester.pump();

    final restoredRect = tester.getRect(avatarFinder);
    expect(restoredRect.right, lessThanOrEqualTo(348.5));
    expect(restoredRect.bottom, lessThanOrEqualTo(628.5));
  });
}
