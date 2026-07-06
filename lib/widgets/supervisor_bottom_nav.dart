import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SupervisorNavDestination { none, home, history, help, newReminder }

class SupervisorBottomNav extends StatelessWidget {
  final SupervisorNavDestination selected;

  const SupervisorBottomNav({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SupervisorNavItem(
                icon: Icons.home,
                label: 'Início',
                selected: selected == SupervisorNavDestination.home,
                onTap: selected == SupervisorNavDestination.home
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/supervisor-dashboard',
                        (route) => false,
                      ),
              ),
              _SupervisorNavItem(
                icon: Icons.add_circle,
                label: 'Novo',
                selected: selected == SupervisorNavDestination.newReminder,
                onTap: selected == SupervisorNavDestination.newReminder
                    ? null
                    : () => Navigator.pushNamed(context, '/new-reminder'),
              ),
              _SupervisorNavItem(
                icon: Icons.history,
                label: 'Histórico',
                selected: selected == SupervisorNavDestination.history,
                onTap: selected == SupervisorNavDestination.history
                    ? null
                    : () => Navigator.pushNamed(context, '/activity-history'),
              ),
              _SupervisorNavItem(
                icon: Icons.help_center,
                label: 'Ajuda',
                selected: selected == SupervisorNavDestination.help,
                onTap: selected == SupervisorNavDestination.help
                    ? null
                    : () => Navigator.pushNamed(context, '/supervisor-help'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupervisorNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SupervisorNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: itemColor),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
