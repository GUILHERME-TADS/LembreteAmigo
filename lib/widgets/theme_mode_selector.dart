import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    super.key,
    this.large = false,
    this.showDescription = true,
  });

  final bool large;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, selectedMode, _) {
        return Semantics(
          container: true,
          label: 'Aparência do aplicativo',
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(large ? 20 : 16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contrast_rounded,
                      color: colors.primary,
                      size: large ? 30 : 24,
                    ),
                    const SizedBox(width: AppSpacing.stackSm),
                    Expanded(
                      child: Text(
                        'Aparência',
                        style:
                            (large
                                    ? textTheme.titleLarge
                                    : textTheme.titleMedium)
                                ?.copyWith(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
                if (showDescription) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Escolha um tema ou acompanhe a configuração do celular.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.stackSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThemeChoice(
                      mode: ThemeMode.system,
                      selectedMode: selectedMode,
                      icon: Icons.phone_android_rounded,
                      label: 'Celular',
                      large: large,
                    ),
                    _ThemeChoice(
                      mode: ThemeMode.light,
                      selectedMode: selectedMode,
                      icon: Icons.light_mode_rounded,
                      label: 'Claro',
                      large: large,
                    ),
                    _ThemeChoice(
                      mode: ThemeMode.dark,
                      selectedMode: selectedMode,
                      icon: Icons.dark_mode_rounded,
                      label: 'Escuro',
                      large: large,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.mode,
    required this.selectedMode,
    required this.icon,
    required this.label,
    required this.large,
  });

  final ThemeMode mode;
  final ThemeMode selectedMode;
  final IconData icon;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final selected = mode == selectedMode;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: large ? 24 : 20),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelLarge,
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 12 : 8,
      ),
      onSelected: (_) => AppThemeController.setMode(mode),
    );
  }
}
