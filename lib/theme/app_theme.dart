import 'package:flutter/material.dart';

/// Tokens de design e cores do aplicativo Lembrete Amigo.
class AppColors {
  AppColors._();

  static ColorScheme get _scheme => AppTheme.scheme;

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
  static Color get primaryFixedDim => const Color(0xFF1565C0);
  static Color get onPrimaryFixed => _scheme.onPrimaryContainer;
  static Color get onPrimaryFixedVariant => _scheme.primary;
  static Color get secondary => _scheme.secondary;
  static Color get onSecondary => _scheme.onSecondary;
  static Color get secondaryContainer => _scheme.secondaryContainer;
  static Color get onSecondaryContainer => _scheme.onSecondaryContainer;
  static Color get secondaryFixed => _scheme.secondaryContainer;
  static Color get secondaryFixedDim => const Color(0xFFF57F17);
  static Color get onSecondaryFixed => _scheme.onSecondaryContainer;
  static Color get onSecondaryFixedVariant => _scheme.secondary;
  static Color get tertiary => _scheme.tertiary;
  static Color get onTertiary => _scheme.onTertiary;
  static Color get tertiaryContainer => _scheme.tertiaryContainer;
  static Color get onTertiaryContainer => _scheme.onTertiaryContainer;
  static Color get tertiaryFixed => _scheme.tertiaryContainer;
  static Color get tertiaryFixedDim => const Color(0xFF2E7D32);
  static Color get onTertiaryFixed => _scheme.onTertiaryContainer;
  static Color get onTertiaryFixedVariant => _scheme.tertiary;
  static Color get error => _scheme.error;
  static Color get onError => _scheme.onError;
  static Color get errorContainer => _scheme.errorContainer;
  static Color get onErrorContainer => _scheme.onErrorContainer;
  static Color get success => const Color(0xFF2E7D32);
  static Color get warning => const Color(0xFFE65100);
  static Color get surfaceTint => _scheme.surfaceTint;
  static Color get successContainer => const Color(0xFFE8F5E9);
  static Color get onSuccessContainer => const Color(0xFF124A19);
  static Color get warningContainer => const Color(0xFFFFE8D6);
  static Color get onWarningContainer => const Color(0xFF4A2500);
  static Color get info => voiceFeedbackBlue;
  static Color get videoCallPrimary => const Color(0xFF00897B);
  static Color get videoCallSecondary => const Color(0xFF26A69A);
  static Color get warningAccent => const Color(0xFFFB8C00);
  static Color get infoContainer => const Color(0xFFE3F2FD);
  static Color get onInfoContainer => const Color(0xFF004A71);
  static Color get medicationContainer => const Color(0xFFF3E5F5);
  static Color get onMedicationContainer => medicationsColor;
  static Color get customContainer => const Color(0xFFE0F2F1);
  static Color get onCustomContainer => const Color(0xFF00695C);
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
  static Color get voiceFeedbackBlue => const Color(0xFF0061A4);
  static Color get mealsColor => const Color(0xFFE65100);
  static Color get medicationsColor => const Color(0xFF7B1FA2);
  static Color get customColor => const Color(0xFF546E7A);

  // Períodos do Dia para Orientação Visual de Baixo Letramento
  static Color get morning => const Color(0xFFE65100);
  static Color get morningContainer => const Color(0xFFFFF3E0);
  static Color get onMorningContainer => const Color(0xFFE65100);

  static Color get afternoon => const Color(0xFF0061A4);
  static Color get afternoonContainer => const Color(0xFFE1F5FE);
  static Color get onAfternoonContainer => const Color(0xFF01579B);

  static Color get night => const Color(0xFF311B92);
  static Color get nightContainer => const Color(0xFFEDE7F6);
  static Color get onNightContainer => const Color(0xFF311B92);

  // Status Vitais e Diagnósticos do Dispositivo
  static Color get vitalHealthy => const Color(0xFF2E7D32);
  static Color get vitalHealthyContainer => const Color(0xFFE8F5E9);
  static Color get vitalWarning => const Color(0xFFE65100);
  static Color get vitalWarningContainer => const Color(0xFFFFE8D6);
  static Color get vitalCritical => const Color(0xFFD32F2F);
  static Color get vitalCriticalContainer => const Color(0xFFFFDAD6);

  // Modo Noturno Quente Luz de Vela (Sunset Amber Mode)
  static Color get sunsetAmber => const Color(0xFFFFB300);
  static Color get sunsetAmberContainer => const Color(0xFF3E2723);
  static Color get sunsetAmberBackground => const Color(0xFF1F1610);
  static Color get onSunsetAmberContainer => const Color(0xFFFFE082);
  static Color get sunsetAmberCard => const Color(0xFF2C1F16);

  // Tokens do Relatório Clínico
  static Color get reportPdfCardBackground => const Color(0xFFEDE7F6);
  static Color get reportPdfCardBorder => const Color(0xFF7E57C2);
  static Color get reportPdfPrimary => const Color(0xFF512DA8);
  static Color get reportPdfTitle => const Color(0xFF311B92);
  static Color get reportPdfSubtitle => const Color(0xFF4527A0);

  // Gradientes Atmosféricos por Período
  static LinearGradient get morningAtmosphere => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8F0), Color(0xFFF8F9FA)],
  );

  static LinearGradient get afternoonAtmosphere => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F7FF), Color(0xFFF8F9FA)],
  );

  static LinearGradient get nightAtmosphere => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3F0FA), Color(0xFFF8F9FA)],
  );

  static LinearGradient get candleLightAtmosphere => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3E0), Color(0xFFFFECB3), Color(0xFFF8F9FA)],
  );

  static LinearGradient get sunsetAmberAtmosphere => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2C1F16), Color(0xFF1F1610)],
  );
}

class AppDecorations {
  AppDecorations._();

  /// Decoração com micro-relevo tátil (Soft Skeuomorphism) para botões sênior
  static BoxDecoration tactileButton({
    required Color color,
    required Color borderColor,
    double borderRadius = AppRadius.xl,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 2.0),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
    );
  }

  /// Decoração de Hero Card para destacar o próximo lembrete do dia
  static BoxDecoration heroCard({
    required Color backgroundColor,
    required Color accentColor,
    double borderRadius = AppRadius.xl,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 2.5),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.8),
          blurRadius: 0,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// Decoração de Blíster/Frasco para o controle de estoque
  static BoxDecoration blisterCard({
    required Color statusColor,
    double borderRadius = AppRadius.lg,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Barra de diagnóstico e prontidão do dispositivo
  static BoxDecoration deviceStatusCard() {
    return BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: AppColors.outlineVariant.withValues(alpha: 0.5),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Decoração moderna estilo Bento Grid para módulos do Dashboard do Supervisor
  static BoxDecoration bentoCard({
    Color? backgroundColor,
    Color? borderColor,
    double borderRadius = AppRadius.lg,
    bool elevated = false,
  }) {
    final bg = backgroundColor ?? AppColors.surfaceContainerLowest;
    final border =
        borderColor ?? AppColors.outlineVariant.withValues(alpha: 0.5);
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1.5),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Hero Banner "Paz de Espírito" no Dashboard
  static BoxDecoration peaceOfMindCard({
    required Color statusColor,
    double borderRadius = AppRadius.xl,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          statusColor.withValues(alpha: 0.12),
          AppColors.surfaceContainerLowest,
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: statusColor.withValues(alpha: 0.35),
        width: 2.0,
      ),
      boxShadow: [
        BoxShadow(
          color: statusColor.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Card do Modo Foco Único (One-Thing-at-a-Time) para Idosos
  static BoxDecoration focusHeroCard({
    required Color accentColor,
    Color? backgroundColor,
    double borderRadius = AppRadius.xxl,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accentColor, width: 3.0),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.9),
          blurRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Frasco / Garrafa de Estoque de Medicamentos com nível
  static BoxDecoration pillBottleCard({
    required Color statusColor,
    double borderRadius = AppRadius.xl,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 2.0),
      boxShadow: [
        BoxShadow(
          color: statusColor.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Brilho envolvente para o microfone e onda sonora
  static BoxDecoration soundwaveGlow({required Color glowColor}) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: glowColor.withValues(alpha: 0.15),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.3),
          blurRadius: 18,
          spreadRadius: 4,
        ),
      ],
    );
  }
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
  static const xxl = 32.0;
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

  static ColorScheme get scheme => schemeFor();

  static ColorScheme schemeFor([Brightness brightness = Brightness.light]) {
    if (brightness == Brightness.dark) {
      return ColorScheme.fromSeed(
        seedColor: _brandSeed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFADC6FF),
        onPrimary: const Color(0xFF002E69),
        primaryContainer: const Color(0xFF004494),
        onPrimaryContainer: const Color(0xFFD7E2FF),
        secondary: const Color(0xFFE5C448),
        onSecondary: const Color(0xFF3B2F00),
        secondaryContainer: const Color(0xFF554400),
        onSecondaryContainer: const Color(0xFFFFE16D),
        tertiary: const Color(0xFF87D983),
        onTertiary: const Color(0xFF003A09),
        tertiaryContainer: const Color(0xFF005313),
        onTertiaryContainer: const Color(0xFFA3F69C),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
        errorContainer: const Color(0xFF93000A),
        onErrorContainer: const Color(0xFFFFDAD6),
        surface: const Color(0xFF111418),
        onSurface: const Color(0xFFE1E3E8),
        onSurfaceVariant: const Color(0xFFC4C6D0),
        outline: const Color(0xFF8E9099),
        outlineVariant: const Color(0xFF43474E),
        surfaceDim: const Color(0xFF111418),
        surfaceBright: const Color(0xFF37393E),
        surfaceContainerLowest: const Color(0xFF0C0E11),
        surfaceContainerLow: const Color(0xFF191C20),
        surfaceContainer: const Color(0xFF1D2024),
        surfaceContainerHigh: const Color(0xFF282A2F),
        surfaceContainerHighest: const Color(0xFF33353A),
      );
    }
    return ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF00193C),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD7E2FF),
      onPrimaryContainer: const Color(0xFF001B3F),
      secondary: const Color(0xFF705D00),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFE16D),
      onSecondaryContainer: const Color(0xFF221B00),
      tertiary: const Color(0xFF2E7D32),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFA3F69C),
      onTertiaryContainer: const Color(0xFF002204),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: const Color(0xFFF8F9FA),
      onSurface: const Color(0xFF191C1D),
      onSurfaceVariant: const Color(0xFF43474F),
      outline: const Color(0xFF747781),
      outlineVariant: const Color(0xFFC4C6D1),
      surfaceDim: const Color(0xFFD9DADB),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF3F4F5),
      surfaceContainer: const Color(0xFFEDEEEF),
      surfaceContainerHigh: const Color(0xFFE7E8E9),
      surfaceContainerHighest: const Color(0xFFE1E3E4),
    );
  }

  static ThemeData get theme => light();
  static ThemeData light({bool highContrast = false}) =>
      _build(highContrast, Brightness.light);
  static ThemeData dark({bool highContrast = false}) =>
      _build(highContrast, Brightness.dark);

  static ThemeData _build(
    bool highContrast, [
    Brightness brightness = Brightness.light,
  ]) {
    var scheme = schemeFor(brightness);
    if (highContrast) {
      scheme = scheme.copyWith(
        outline: brightness == Brightness.dark
            ? const Color(0xFFE1E3E8)
            : const Color(0xFF343840),
        outlineVariant: brightness == Brightness.dark
            ? const Color(0xFFC4C6D0)
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
      side: BorderSide(
        color: scheme.outlineVariant,
        width: highContrast ? 2.5 : 1.0,
      ),
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
          success: const Color(0xFF2E7D32),
          successContainer: const Color(0xFFE8F5E9),
          onSuccessContainer: const Color(0xFF124A19),
          warning: const Color(0xFFE65100),
          warningContainer: const Color(0xFFFFE8D6),
          onWarningContainer: const Color(0xFF4A2500),
          chatIncoming: scheme.surfaceContainerHigh,
          chatOutgoing: scheme.primaryContainer,
          medication: const Color(0xFF7B1FA2),
          meal: const Color(0xFFE65100),
          voice: const Color(0xFF0061A4),
        ),
      ],
    );
  }
}
