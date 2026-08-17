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
}
