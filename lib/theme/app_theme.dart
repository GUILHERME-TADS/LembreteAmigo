import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static const _preferenceKey = 'appearance_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    mode.value = ThemeMode.values.firstWhere(
      (item) => item.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  static Future<void> setMode(ThemeMode value) async {
    if (mode.value == value) return;
    mode.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, value.name);
  }

  static Brightness get resolvedBrightness {
    switch (mode.value) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }
}

/// Tokens de compatibilidade. Todas as telas antigas passam a responder ao
/// modo claro/escuro sem manter uma segunda paleta local.
class AppColors {
  AppColors._();

  static ColorScheme get _scheme =>
      AppTheme.schemeFor(AppThemeController.resolvedBrightness);
  static bool get _dark =>
      AppThemeController.resolvedBrightness == Brightness.dark;

  static Color get surface => _scheme.surface;
  static Color get surfaceDim => _scheme.surfaceDim;
  static Color get surfaceBright => _scheme.surfaceBright;
  static Color get surfaceContainerLowest => _scheme.surfaceContainerLowest;
  static Color get surfaceContainerLow => _scheme.surfaceContainerLow;
  static Color get surfaceContainer => _scheme.surfaceContainer;
  static Color get surfaceContainerHigh => _scheme.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _scheme.surfaceContainerHighest;
  static Color get onSurface => _scheme.onSurface;
  static Color get onSurfaceVariant => _scheme.onSurfaceVariant;
  static Color get outline => _scheme.outline;
  static Color get outlineVariant => _scheme.outlineVariant;
  static Color get primary => _scheme.primary;
  static Color get onPrimary => _scheme.onPrimary;
  static Color get primaryContainer => _scheme.primaryContainer;
  static Color get onPrimaryContainer => _scheme.onPrimaryContainer;
  static Color get inversePrimary => _scheme.inversePrimary;
  static Color get primaryFixed => _scheme.primaryContainer;
  static Color get primaryFixedDim =>
      _dark ? const Color(0xFFABC7FF) : const Color(0xFFABC7FF);
  static Color get onPrimaryFixed => _scheme.onPrimaryContainer;
  static Color get onPrimaryFixedVariant => _scheme.primary;
  static Color get secondary => _scheme.secondary;
  static Color get onSecondary => _scheme.onSecondary;
  static Color get secondaryContainer => _scheme.secondaryContainer;
  static Color get onSecondaryContainer => _scheme.onSecondaryContainer;
  static Color get secondaryFixed => _scheme.secondaryContainer;
  static Color get secondaryFixedDim =>
      _dark ? const Color(0xFFE9C400) : const Color(0xFFE9C400);
  static Color get onSecondaryFixed => _scheme.onSecondaryContainer;
  static Color get onSecondaryFixedVariant => _scheme.secondary;
  static Color get tertiary => _scheme.tertiary;
  static Color get onTertiary => _scheme.onTertiary;
  static Color get tertiaryContainer => _scheme.tertiaryContainer;
  static Color get onTertiaryContainer => _scheme.onTertiaryContainer;
  static Color get tertiaryFixed => _scheme.tertiaryContainer;
  static Color get tertiaryFixedDim =>
      _dark ? const Color(0xFF88D982) : const Color(0xFF88D982);
  static Color get onTertiaryFixed => _scheme.onTertiaryContainer;
  static Color get onTertiaryFixedVariant => _scheme.tertiary;
  static Color get error => _scheme.error;
  static Color get onError => _scheme.onError;
  static Color get errorContainer => _scheme.errorContainer;
  static Color get onErrorContainer => _scheme.onErrorContainer;
  static Color get success =>
      _dark ? const Color(0xFF88D982) : const Color(0xFF2E7D32);
  static Color get warning =>
      _dark ? const Color(0xFFFFB77D) : const Color(0xFFB94E00);
  static Color get surfaceTint => _scheme.surfaceTint;
  static Color get successContainer =>
      _dark ? const Color(0xFF005313) : const Color(0xFFE8F5E9);
  static Color get onSuccessContainer =>
      _dark ? const Color(0xFFA3F69C) : const Color(0xFF124A19);
  static Color get warningContainer =>
      _dark ? const Color(0xFF633200) : const Color(0xFFFFE8D6);
  static Color get onWarningContainer =>
      _dark ? const Color(0xFFFFDCC5) : const Color(0xFF4A2500);
  static Color get info => voiceFeedbackBlue;
  static Color get infoContainer =>
      _dark ? const Color(0xFF004A71) : const Color(0xFFE3F2FD);
  static Color get onInfoContainer =>
      _dark ? const Color(0xFFCDE5FF) : const Color(0xFF004A71);
  static Color get medicationContainer =>
      _dark ? const Color(0xFF542469) : const Color(0xFFF3E5F5);
  static Color get onMedicationContainer => medicationsColor;
  static Color get customContainer =>
      _dark ? const Color(0xFF294A48) : const Color(0xFFE0F2F1);
  static Color get onCustomContainer =>
      _dark ? const Color(0xFFA9D6D1) : const Color(0xFF00695C);
  static Color get chatIncoming => surfaceContainerLowest;
  static Color get chatOutgoing => primaryContainer;
  static Color get cameraSurface => const Color(0xFF050607);
  static Color get onCameraSurface => const Color(0xFFFFFFFF);
  static Color get scrim => const Color(0x99000000);
  static Color get shadow => const Color(0x33000000);
  static Color get disabled => onSurface.withValues(alpha: 0.38);
  static Color get surfaceVariant => _scheme.surfaceContainerHighest;
  static Color get inverseSurface => _scheme.inverseSurface;
  static Color get inverseOnSurface => _scheme.onInverseSurface;
  static Color get background => _scheme.surface;
  static Color get onBackground => _scheme.onSurface;
  static Color get voiceFeedbackBlue =>
      _dark ? const Color(0xFF9ECAFF) : const Color(0xFF0061A4);
  static Color get mealsColor =>
      _dark ? const Color(0xFFFFB77D) : const Color(0xFF9A4E0F);
  static Color get medicationsColor =>
      _dark ? const Color(0xFFE7B5FF) : const Color(0xFF7B1FA2);
  static Color get customColor =>
      _dark ? const Color(0xFFB8C8D0) : const Color(0xFF546E7A);
}

class AppTypography {
  static const fontFamily = 'Roboto';
  static const fontFallback = <String>['Roboto', 'sans-serif'];
  static const headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  static const headlineLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  static const headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );
  static const bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );
  static const labelCaps = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.2,
  );
  static const supervisorData = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
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
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const full = 9999.0;
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.chatIncoming,
    required this.chatOutgoing,
    required this.medication,
    required this.meal,
    required this.voice,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color chatIncoming;
  final Color chatOutgoing;
  final Color medication;
  final Color meal;
  final Color voice;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? chatIncoming,
    Color? chatOutgoing,
    Color? medication,
    Color? meal,
    Color? voice,
  }) => AppSemanticColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    chatIncoming: chatIncoming ?? this.chatIncoming,
    chatOutgoing: chatOutgoing ?? this.chatOutgoing,
    medication: medication ?? this.medication,
    meal: meal ?? this.meal,
    voice: voice ?? this.voice,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      chatIncoming: Color.lerp(chatIncoming, other.chatIncoming, t)!,
      chatOutgoing: Color.lerp(chatOutgoing, other.chatOutgoing, t)!,
      medication: Color.lerp(medication, other.medication, t)!,
      meal: Color.lerp(meal, other.meal, t)!,
      voice: Color.lerp(voice, other.voice, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get typography => Theme.of(this).textTheme;
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

class AppTheme {
  AppTheme._();

  static const _brandSeed = Color(0xFF002D62);

  static ColorScheme schemeFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFABC7FF) : const Color(0xFF00193C),
      onPrimary: dark ? const Color(0xFF002F65) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF24467C)
          : const Color(0xFFD7E2FF),
      onPrimaryContainer: dark
          ? const Color(0xFFD7E2FF)
          : const Color(0xFF001B3F),
      secondary: dark ? const Color(0xFFE9C400) : const Color(0xFF705D00),
      onSecondary: dark ? const Color(0xFF3A3000) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF544600)
          : const Color(0xFFFFE16D),
      onSecondaryContainer: dark
          ? const Color(0xFFFFE16D)
          : const Color(0xFF221B00),
      tertiary: dark ? const Color(0xFF88D982) : const Color(0xFF006E1C),
      onTertiary: dark ? const Color(0xFF003909) : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF005312)
          : const Color(0xFFA3F69C),
      onTertiaryContainer: dark
          ? const Color(0xFFA3F69C)
          : const Color(0xFF002204),
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: dark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6),
      onErrorContainer: dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF410002),
      surface: dark ? const Color(0xFF101418) : const Color(0xFFF8F9FA),
      onSurface: dark ? const Color(0xFFE2E2E7) : const Color(0xFF191C1D),
      onSurfaceVariant: dark
          ? const Color(0xFFC4C6D0)
          : const Color(0xFF43474F),
      outline: dark ? const Color(0xFF8E909A) : const Color(0xFF747781),
      outlineVariant: dark ? const Color(0xFF44474F) : const Color(0xFFC4C6D1),
      surfaceDim: dark ? const Color(0xFF101418) : const Color(0xFFD9DADB),
      surfaceBright: dark ? const Color(0xFF363A3F) : const Color(0xFFFFFFFF),
      surfaceContainerLowest: dark
          ? const Color(0xFF0B0F13)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark
          ? const Color(0xFF181C20)
          : const Color(0xFFF3F4F5),
      surfaceContainer: dark
          ? const Color(0xFF1C2024)
          : const Color(0xFFEDEEEF),
      surfaceContainerHigh: dark
          ? const Color(0xFF272B30)
          : const Color(0xFFE7E8E9),
      surfaceContainerHighest: dark
          ? const Color(0xFF32363B)
          : const Color(0xFFE1E3E4),
    );
  }

  static ThemeData get theme => light();
  static ThemeData get darkTheme => dark();
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast);
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast);

  static ThemeData _build(Brightness brightness, bool highContrast) {
    var scheme = schemeFor(brightness);
    final dark = brightness == Brightness.dark;
    if (highContrast) {
      scheme = scheme.copyWith(
        outline: dark ? const Color(0xFFDDE1EA) : const Color(0xFF343840),
        outlineVariant: dark
            ? const Color(0xFFAEB1BB)
            : const Color(0xFF656870),
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
    );
    final text = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: scheme.outlineVariant),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardColor: scheme.surfaceContainerLowest,
      dividerColor: scheme.outlineVariant,
      textTheme: text,
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        weight: 700,
        fill: 1,
      ),
      primaryIconTheme: IconThemeData(
        color: scheme.primary,
        weight: 800,
        fill: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.primary,
          fontSize: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.primary,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          textStyle: text.labelLarge,
          shape: rounded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: text.labelLarge,
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: text.labelLarge,
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          shape: rounded,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          shape: rounded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        elevation: 2,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: rounded,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: text.labelMedium,
        unselectedLabelStyle: text.labelMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: rounded,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.onSurface.withValues(alpha: 0.12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: text.labelLarge!,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm / 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.stackMd,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors(
          success: dark ? const Color(0xFF88D982) : const Color(0xFF2E7D32),
          successContainer: dark
              ? const Color(0xFF005313)
              : const Color(0xFFE8F5E9),
          onSuccessContainer: dark
              ? const Color(0xFFA3F69C)
              : const Color(0xFF124A19),
          warning: dark ? const Color(0xFFFFB77D) : const Color(0xFFB94E00),
          warningContainer: dark
              ? const Color(0xFF633200)
              : const Color(0xFFFFE8D6),
          onWarningContainer: dark
              ? const Color(0xFFFFDCC5)
              : const Color(0xFF4A2500),
          chatIncoming: scheme.surfaceContainerHigh,
          chatOutgoing: scheme.primaryContainer,
          medication: dark ? const Color(0xFFE7B5FF) : const Color(0xFF7B1FA2),
          meal: dark ? const Color(0xFFFFB77D) : const Color(0xFF9A4E0F),
          voice: dark ? const Color(0xFF9ECAFF) : const Color(0xFF0061A4),
        ),
      ],
    );
  }
}
