import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';

enum SupervisorNavDestination { none, home, history, help, newReminder }

class SupervisorBottomNav extends StatefulWidget {
  final SupervisorNavDestination selected;

  const SupervisorBottomNav({super.key, required this.selected});

  @override
  State<SupervisorBottomNav> createState() => _SupervisorBottomNavState();
}

class _SupervisorBottomNavState extends State<SupervisorBottomNav> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final conn = await SessionRoleService.isSupervisorConnected();
    if (mounted) {
      setState(() {
        _isConnected = conn;
      });
    }
  }

  void _handleTap(String routeName, BuildContext context) {
    final protectedRoutes = ['/new-reminder', '/activity-history'];

    if (protectedRoutes.contains(routeName) && !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conecte um dispositivo de idoso para acessar esta tela.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (routeName == '/supervisor-dashboard') {
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    } else {
      Navigator.pushNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        constraints: const BoxConstraints(minHeight: 76),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SupervisorNavItem(
                icon: Icons.home,
                label: 'Início',
                selected: widget.selected == SupervisorNavDestination.home,
                onTap: widget.selected == SupervisorNavDestination.home
                    ? null
                    : () => _handleTap('/supervisor-dashboard', context),
              ),
              _SupervisorNavItem(
                icon: Icons.add_circle,
                label: 'Novo lembrete',
                selected:
                    widget.selected == SupervisorNavDestination.newReminder,
                opacity: _isConnected ? 1.0 : 0.4,
                onTap: widget.selected == SupervisorNavDestination.newReminder
                    ? null
                    : () => _handleTap('/new-reminder', context),
              ),
              _SupervisorNavItem(
                icon: Icons.history,
                label: 'Histórico',
                selected: widget.selected == SupervisorNavDestination.history,
                opacity: _isConnected ? 1.0 : 0.4,
                onTap: widget.selected == SupervisorNavDestination.history
                    ? null
                    : () => _handleTap('/activity-history', context),
              ),
              _SupervisorNavItem(
                icon: Icons.help_center,
                label: 'Ajuda',
                selected: widget.selected == SupervisorNavDestination.help,
                onTap: widget.selected == SupervisorNavDestination.help
                    ? null
                    : () => _handleTap('/supervisor-help', context),
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
  final double opacity;

  const _SupervisorNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: itemColor),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
