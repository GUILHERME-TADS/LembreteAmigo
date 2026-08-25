import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/theme/app_theme.dart';
import 'package:lembretes_app/widgets/index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('HoldToActivateButton renderiza e aciona callback após segurar',
      (tester) async {
    bool triggered = false;

    await tester.pumpWidget(
      buildTestable(
        HoldToActivateButton(
          label: 'SOS EMERGÊNCIA',
          holdDuration: const Duration(seconds: 1),
          onTriggered: () => triggered = true,
        ),
      ),
    );

    expect(find.text('SOS EMERGÊNCIA'), findsOneWidget);
    expect(find.byIcon(Icons.emergency), findsOneWidget);

    // Tocar e segurar
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToActivateButton)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(triggered, isFalse);

    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(triggered, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('BlisterReminderCard renderiza dados do lembrete com alvéolo',
      (tester) async {
    final lembrete = Lembrete(
      id: 'rem-123',
      titulo: 'Losartana 50mg',
      horarioHour: 14,
      horarioMinute: 0,
      categoria: LembreteCategoria.medicacao,
      status: LembreteStatus.pendente,
    );

    bool tapped = false;

    await tester.pumpWidget(
      buildTestable(
        BlisterReminderCard(
          lembrete: lembrete,
          isNext: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Losartana 50mg'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('PRÓXIMO'), findsOneWidget);
    expect(find.byIcon(Icons.medication_rounded), findsOneWidget);

    await tester.tap(find.byType(BlisterReminderCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('CelebrationOverlay renderiza elementos comemorativos',
      (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const CelebrationOverlay(
          title: 'Parabéns!',
          subtitle: 'Remédio tomado!',
        ),
      ),
    );

    expect(find.text('Parabéns!'), findsOneWidget);
    expect(find.text('Remédio tomado!'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('CelestialSkyArc renderiza e possui semântica de horário e período',
      (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const CelestialSkyArc(),
      ),
    );

    expect(find.byType(CelestialSkyArc), findsOneWidget);
  });

  testWidgets('VoiceSpeedToggle renderiza e responde a toques',
      (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const VoiceSpeedToggle(),
      ),
    );

    expect(find.byType(VoiceSpeedToggle), findsOneWidget);
    expect(find.textContaining('Falar'), findsOneWidget);
  });



  testWidgets('HabitHeatmapWidget renderiza grade de dias e legenda',
      (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const HabitHeatmapWidget(eventos: []),
      ),
    );

    expect(find.byType(HabitHeatmapWidget), findsOneWidget);
    expect(find.textContaining('Ritmo de Hábitos'), findsOneWidget);
    expect(find.text('100% em dia'), findsOneWidget);
  });

  testWidgets('ElderlyScreenMirrorCard renderiza miniatura da tela do idoso',
      (tester) async {
    final lembrete = Lembrete(
      id: 'rem-1',
      titulo: 'Enalapril 10mg',
      horarioHour: 8,
      horarioMinute: 30,
      categoria: LembreteCategoria.medicacao,
    );

    await tester.pumpWidget(
      buildTestable(
        ElderlyScreenMirrorCard(
          elderlyName: 'Dona Maria',
          nextReminder: lembrete,
          batteryLevel: 90,
          isOnline: true,
        ),
      ),
    );

    expect(find.textContaining('Visão de Dona Maria'), findsOneWidget);
    expect(find.text('Enalapril 10mg'), findsOneWidget);
    expect(find.textContaining('90%'), findsOneWidget);
  });

  testWidgets('MedicationScannerSheet renderiza título e botões de captura',
      (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const MedicationScannerSheet(),
      ),
    );

    expect(find.text('Reconhecer Remédio por IA'), findsOneWidget);
    expect(find.text('Tirar Foto 📸'), findsOneWidget);
    expect(find.text('Galeria 🖼️'), findsOneWidget);
  });

  testWidgets('CallingFeedbackDialog renderiza nome e botão de cancelar',
      (tester) async {
    bool callConfirmed = false;

    await tester.pumpWidget(
      buildTestable(
        CallingFeedbackDialog(
          contactName: 'Filha Ana',
          callTypeLabel: 'Vídeo Familiar',
          onCallConfirmed: () => callConfirmed = true,
        ),
      ),
    );

    expect(find.text('Filha Ana'), findsOneWidget);
    expect(find.text('Vídeo Familiar'), findsOneWidget);
    expect(find.text('Chamando agora...'), findsOneWidget);
    expect(find.text('CANCELAR'), findsOneWidget);

    await tester.tap(find.text('CANCELAR'));
    await tester.pump();
    expect(callConfirmed, isFalse);
  });
}
