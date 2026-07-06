import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<BottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return GestureDetector(
                onTap: item.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? AppColors.onSecondaryContainer
                            : AppColors.onSurfaceVariant,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.labelCaps.copyWith(
                          fontSize: 16,
                          color: isSelected
                              ? AppColors.onSecondaryContainer
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class SeniorButton extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? leadingBackgroundColor;
  final VoidCallback? onTap;

  const SeniorButton({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingBackgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.surfaceContainerLowest;
    final fgColor = foregroundColor ?? AppColors.primary;
    final leadBg = leadingBackgroundColor ?? AppColors.primaryContainer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD1D1D1),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: leadBg,
                shape: BoxShape.circle,
              ),
              child: Center(child: leading),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.headlineMd.copyWith(color: fgColor),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMd.copyWith(
                      color: fgColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.chevron_right,
                color: fgColor,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const TopAppBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
          child: Row(
            children: [
              if (leading != null) leading! else const SizedBox(width: 48),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class SeniorFormField extends StatelessWidget {
  final String label;
  final String? hintText;
  final bool obscureText;
  final TextEditingController? controller;

  const SeniorFormField({
    super.key,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: AppTypography.bodyMd,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
