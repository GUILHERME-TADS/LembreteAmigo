import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SeniorCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Color? borderColor;
  final Color? iconBgColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const SeniorCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.borderColor,
    this.iconBgColor,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bColor = borderColor ?? AppColors.primary;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: bColor, width: 4),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: iconBgColor ?? AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconTheme(
                  data: const IconThemeData(size: 40, color: Colors.white),
                  child: icon,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
