import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lembretes_app/screens/test_hub_screen.dart';
import 'package:lembretes_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layout com Fonte Gigante (Acessibilidade Idoso)', () {
    testWidgets('TestHubScreen renderiza em TextScaler 2.0x sem estourar layout', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(380, 700));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(380, 700),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const TestHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Central de Testes & Simulações'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Scroll para verificar que a página é rolável
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
