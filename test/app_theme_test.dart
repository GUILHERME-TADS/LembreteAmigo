import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lembretes_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tema claro possui componentes e contraste essenciais', () {
    final theme = AppTheme.light();
    final scheme = theme.colorScheme;
    expect(_contrast(scheme.primary, scheme.onPrimary), greaterThan(4.5));
    expect(_contrast(scheme.surface, scheme.onSurface), greaterThan(7));
    expect(theme.cardTheme.shape, isNotNull);
    expect(theme.inputDecorationTheme.focusedBorder, isNotNull);
    expect(theme.elevatedButtonTheme.style, isNotNull);
    expect(theme.dialogTheme.shape, isNotNull);
    expect(theme.extension<AppSemanticColors>(), isNotNull);
  });

  test('alto contraste configura bordas e tokens com visibilidade', () {
    final normalTheme = AppTheme.light(highContrast: false);
    final highContrastTheme = AppTheme.light(highContrast: true);

    expect(
      highContrastTheme.colorScheme.outline,
      isNot(equals(normalTheme.colorScheme.outline)),
    );
  });

  test('AppColors expoe tokens consistentes', () {
    expect(AppColors.primary, isNotNull);
    expect(AppColors.surface, isNotNull);
    expect(AppColors.medicationsColor, isNotNull);
    expect(AppColors.mealsColor, isNotNull);
    expect(AppColors.success, isNotNull);
    expect(AppColors.error, isNotNull);
    expect(AppColors.morningAtmosphere, isNotNull);
    expect(AppColors.afternoonAtmosphere, isNotNull);
    expect(AppColors.nightAtmosphere, isNotNull);
  });

  test('tema escuro e decorações Bento são construídos com sucesso', () {
    final darkTheme = AppTheme.dark();
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.colorScheme.primary, isNotNull);

    final bento = AppDecorations.bentoCard();
    expect(bento.borderRadius, isNotNull);

    final hero = AppDecorations.peaceOfMindCard(statusColor: AppColors.success);
    expect(hero.gradient, isNotNull);
  });
}

double _contrast(Color first, Color second) {
  final bright = first.computeLuminance();
  final dark = second.computeLuminance();
  final lighter = bright > dark ? bright : dark;
  final darker = bright > dark ? dark : bright;
  return (lighter + 0.05) / (darker + 0.05);
}
