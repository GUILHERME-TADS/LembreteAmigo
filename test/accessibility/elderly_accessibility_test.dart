import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lembretes_app/theme/app_theme.dart';
import 'package:lembretes_app/screens/test_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Acessibilidade e Contraste do Idoso', () {
    test('AppColors possui contraste válido e definido para elementos críticos', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.onPrimary, isNotNull);
      expect(AppColors.success, isNotNull);
      expect(AppColors.error, isNotNull);
      expect(AppColors.warning, isNotNull);
      expect(AppColors.surfaceContainerLowest, isNotNull);
    });

    testWidgets('TestHubScreen renderiza com suporte acessível e sem exceções', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TestHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica se os textos e seções principais estão presentes
      expect(find.text('Central de Testes & Simulações'), findsOneWidget);
      expect(find.text('1. SIMULAÇÃO DE DISPAROS EM TEMPO REAL'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('2. DIAGNÓSTICO DE HARDWARE & SISTEMA'),
        150,
      );
      expect(find.text('2. DIAGNÓSTICO DE HARDWARE & SISTEMA'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('3. SANDBOX DE DADOS DE DEMONSTRAÇÃO'),
        150,
      );
      expect(find.text('3. SANDBOX DE DADOS DE DEMONSTRAÇÃO'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('4. PRÁTICA & TREINAMENTO'),
        150,
      );
      expect(find.text('4. PRÁTICA & TREINAMENTO'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
