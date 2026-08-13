import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lembretes_app/theme/app_theme.dart';
import 'package:lembretes_app/widgets/theme_mode_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppThemeController.mode.value = ThemeMode.system;
  });

  test('temas claro e escuro possuem componentes e contraste essenciais', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.primary, scheme.onPrimary), greaterThan(4.5));
      expect(_contrast(scheme.surface, scheme.onSurface), greaterThan(7));
      expect(theme.cardTheme.shape, isNotNull);
      expect(theme.inputDecorationTheme.focusedBorder, isNotNull);
      expect(theme.elevatedButtonTheme.style, isNotNull);
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.extension<AppSemanticColors>(), isNotNull);
    }
  });

  test('preferencia de tema e carregada e persistida', () async {
    SharedPreferences.setMockInitialValues({'appearance_theme_mode': 'dark'});

    await AppThemeController.load();
    expect(AppThemeController.mode.value, ThemeMode.dark);

    await AppThemeController.setMode(ThemeMode.light);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('appearance_theme_mode'), 'light');
  });

  testWidgets('seletor de aparencia nao estoura em tela compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: ThemeModeSelector(large: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Celular'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(AppThemeController.mode.value, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color first, Color second) {
  final bright = first.computeLuminance();
  final dark = second.computeLuminance();
  final lighter = bright > dark ? bright : dark;
  final darker = bright > dark ? dark : bright;
  return (lighter + 0.05) / (darker + 0.05);
}
