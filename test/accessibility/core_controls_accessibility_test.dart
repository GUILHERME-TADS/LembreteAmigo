import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lembretes_app/theme/app_theme.dart';
import 'package:lembretes_app/widgets/hold_to_activate_button.dart';
import 'package:lembretes_app/widgets/senior_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget testApp(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );
  }

  group('Controles essenciais acessíveis', () {
    testWidgets('botão principal expõe rótulo e área tátil ampla', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          SeniorButton(
            label: 'Pedir ajuda',
            icon: Icons.support_agent,
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('Pedir ajuda')), findsWidgets);
      expect(
        tester.getSize(find.byType(SeniorButton)).height,
        greaterThanOrEqualTo(48),
      );
      semantics.dispose();
    });

    testWidgets('botão de emergência descreve a ativação prolongada', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          HoldToActivateButton(label: 'Acionar emergência', onTriggered: () {}),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('Acionar emergência')), findsWidgets);
      expect(
        find.semantics.byHint(RegExp('Pressione e segure para ativar')),
        findsWidgets,
      );
      expect(
        tester.getSize(find.byType(HoldToActivateButton)).height,
        greaterThanOrEqualTo(48),
      );
      semantics.dispose();
    });

    testWidgets('confirmação prolongada expõe instrução ao leitor de tela', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          SeniorHoldButton(
            label: 'Confirmar medicação',
            icon: Icons.medication,
            backgroundColor: AppColors.successContainer,
            foregroundColor: AppColors.onSuccessContainer,
            onTriggered: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Confirmar medicação')),
        findsWidgets,
      );
      expect(
        find.semantics.byHint(RegExp('Pressione e segure para confirmar')),
        findsWidgets,
      );
      semantics.dispose();
    });

    testWidgets('botão principal aceita texto ampliado a 200% sem falhar', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          SeniorButton(
            label: 'Já tomei meu medicamento',
            icon: Icons.check_circle,
            onPressed: () {},
          ),
          textScale: 2.0,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Já tomei meu medicamento'), findsOneWidget);
    });
  });
}
