import 'package:flutter/material.dart';

class AppColors {
  static const surface = Color(0xFFF8F9FA);
  static const surfaceDim = Color(0xFFD9DADB);
  static const surfaceBright = Color(0xFFF8F9FA);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF43474F);
  static const outline = Color(0xFF747781);
  static const outlineVariant = Color(0xFFC4C6D1);

  static const primary = Color(0xFF00193C);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF002D62);
  static const onPrimaryContainer = Color(0xFF7796D1);
  static const inversePrimary = Color(0xFFABC7FF);
  static const primaryFixed = Color(0xFFD7E2FF);
  static const primaryFixedDim = Color(0xFFABC7FF);
  static const onPrimaryFixed = Color(0xFF001B3F);
  static const onPrimaryFixedVariant = Color(0xFF24467C);

  static const secondary = Color(0xFF705D00);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFCD400);
  static const onSecondaryContainer = Color(0xFF6E5C00);
  static const secondaryFixed = Color(0xFFFFE16D);
  static const secondaryFixedDim = Color(0xFFE9C400);
  static const onSecondaryFixed = Color(0xFF221B00);
  static const onSecondaryFixedVariant = Color(0xFF544600);

  static const tertiary = Color(0xFF001F03);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF003709);
  static const onTertiaryContainer = Color(0xFF58A756);
  static const tertiaryFixed = Color(0xFFA3F69C);
  static const tertiaryFixedDim = Color(0xFF88D982);
  static const onTertiaryFixed = Color(0xFF002204);
  static const onTertiaryFixedVariant = Color(0xFF005312);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const surfaceTint = Color(0xFF3E5E95);
  static const surfaceVariant = Color(0xFFE1E3E4);
  static const inverseSurface = Color(0xFF2E3132);
  static const inverseOnSurface = Color(0xFFF0F1F2);
  static const background = Color(0xFFF8F9FA);
  static const onBackground = Color(0xFF191C1D);

  static const voiceFeedbackBlue = Color(0xFF0061A4);
  static const mealsColor = Color(0xFFD4762C);
  static const medicationsColor = Color(0xFF7B1FA2);
  static const customColor = Color(0xFF546E7A);
}

class AppTypography {
  static const fontFamily = 'Atkinson Hyperlegible Next';

  static const headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
  );

  static const headlineLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static const bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );

  static const bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.6,
  );

  static const labelCaps = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
  );

  static const supervisorData = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    height: 1.4,
  );
}

class AppSpacing {
  static const touchTargetMin = 64.0;
  static const gutter = 24.0;
  static const marginMobile = 20.0;
  static const marginDesktop = 48.0;
  static const stackSm = 12.0;
  static const stackMd = 24.0;
  static const stackLg = 48.0;
}

class AppRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 24.0;
  static const full = 9999.0;
}

class AppTheme {
  static TextTheme get _boldTextTheme => const TextTheme(
    bodyLarge: TextStyle(fontWeight: FontWeight.bold),
    bodyMedium: TextStyle(fontWeight: FontWeight.bold),
    bodySmall: TextStyle(fontWeight: FontWeight.bold),
    labelLarge: TextStyle(fontWeight: FontWeight.bold),
    labelMedium: TextStyle(fontWeight: FontWeight.bold),
    labelSmall: TextStyle(fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontWeight: FontWeight.bold),
    titleSmall: TextStyle(fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(fontWeight: FontWeight.bold),
    displayLarge: TextStyle(fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontWeight: FontWeight.bold),
  );

  static IconThemeData get _boldIconTheme => const IconThemeData(
    weight: 900.0,
    fill: 1.0,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.fontFamily,
    textTheme: _boldTextTheme,
    iconTheme: _boldIconTheme,
    primaryIconTheme: _boldIconTheme,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      surfaceTint: AppColors.surfaceTint,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );

  static ThemeData get highContrastTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.fontFamily,
    textTheme: _boldTextTheme,
    iconTheme: _boldIconTheme,
    primaryIconTheme: _boldIconTheme,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Colors.black,
      onPrimary: Colors.white,
      primaryContainer: Colors.black,
      onPrimaryContainer: Colors.yellow,
      secondary: Colors.black,
      onSecondary: Colors.yellow,
      secondaryContainer: Colors.yellow,
      onSecondaryContainer: Colors.black,
      tertiary: Colors.black,
      onTertiary: Colors.white,
      tertiaryContainer: Colors.black,
      onTertiaryContainer: Colors.greenAccent,
      error: Colors.red,
      onError: Colors.white,
      errorContainer: Colors.red,
      onErrorContainer: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black,
      outline: Colors.black,
      outlineVariant: Colors.black,
      inverseSurface: Colors.black,
      surfaceTint: Colors.black,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
}
