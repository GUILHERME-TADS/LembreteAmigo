import 'package:flutter/material.dart';

import '../models/lembrete.dart';
import '../theme/app_theme.dart';

class ReminderStatusBadge extends StatelessWidget {
  final LembreteStatus status;
  final bool compact;
  final Color? accentColor;

  const ReminderStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final data = _statusData(status, accentColor: accentColor);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: compact ? 14 : 16, color: data.foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              data.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w800,
                color: data.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_StatusBadgeData _statusData(LembreteStatus status, {Color? accentColor}) {
  switch (status) {
    case LembreteStatus.adiado:
      return const _StatusBadgeData(
        label: 'MAIS TARDE',
        icon: Icons.schedule,
        foreground: AppColors.onSecondaryFixedVariant,
        background: AppColors.secondaryFixed,
      );
    case LembreteStatus.perdido:
      return const _StatusBadgeData(
        label: 'NAO FEITO',
        icon: Icons.cancel_outlined,
        foreground: AppColors.onError,
        background: AppColors.error,
      );
    case LembreteStatus.precisaDeAjuda:
      return const _StatusBadgeData(
        label: 'PRECISA DE AJUDA',
        icon: Icons.support_agent,
        foreground: AppColors.onError,
        background: AppColors.error,
      );
    case LembreteStatus.concluido:
      return const _StatusBadgeData(
        label: 'PRONTO',
        icon: Icons.check_circle,
        foreground: AppColors.onTertiaryFixedVariant,
        background: AppColors.tertiaryFixedDim,
      );
    case LembreteStatus.concluidoComFoto:
      return const _StatusBadgeData(
        label: 'PRONTO COM FOTO',
        icon: Icons.photo_camera,
        foreground: AppColors.onTertiaryFixedVariant,
        background: AppColors.tertiaryFixedDim,
      );
    case LembreteStatus.confirmadoPeloCuidador:
      return const _StatusBadgeData(
        label: 'AJUDANTE CONFIRMOU',
        icon: Icons.verified,
        foreground: AppColors.onTertiaryFixedVariant,
        background: AppColors.tertiaryFixedDim,
      );
    case LembreteStatus.pendente:
      final color = accentColor ?? AppColors.primary;
      return _StatusBadgeData(
        label: 'FALTA FAZER',
        icon: Icons.info_outline,
        foreground: Colors.white,
        background: color,
      );
  }
}

class _StatusBadgeData {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _StatusBadgeData({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });
}
