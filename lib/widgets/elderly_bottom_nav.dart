import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import 'message_unread_badge.dart';

enum ElderlyNavDestination { none, home, reminders, radio, help }

class ElderlyBottomNav extends StatefulWidget {
  final ElderlyNavDestination selected;

  const ElderlyBottomNav({super.key, required this.selected});

  @override
  State<ElderlyBottomNav> createState() => _ElderlyBottomNavState();
}

class _ElderlyBottomNavState extends State<ElderlyBottomNav> {
  bool _isProcessingAction = false;

  void _stopAllAudioAndTts() {
    TTSService.instance.parar();
  }

  void _handleTap(String routeName, BuildContext context) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      _stopAllAudioAndTts();
      if (routeName == '/elderly-home') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          routeName,
          (route) => false,
        );
      } else {
        Navigator.pushNamed(context, routeName);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

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
              _ElderlyNavItem(
                icon: Icons.home,
                label: 'Início',
                selected: widget.selected == ElderlyNavDestination.home,
                onTap: widget.selected == ElderlyNavDestination.home
                    ? null
                    : () => _handleTap('/elderly-home', context),
              ),
              _ElderlyNavItem(
                icon: Icons.list_alt,
                label: 'Lembretes',
                selected: widget.selected == ElderlyNavDestination.reminders,
                onTap: widget.selected == ElderlyNavDestination.reminders
                    ? null
                    : () => _handleTap('/all-reminders', context),
              ),
              _ElderlyNavItem(
                icon: Icons.radio,
                label: 'Rádio',
                selected: widget.selected == ElderlyNavDestination.radio,
                onTap: widget.selected == ElderlyNavDestination.radio
                    ? null
                    : () => _handleTap('/elderly-radio', context),
              ),
              _ElderlyNavItem(
                icon: Icons.help_center,
                label: 'Ajuda',
                showMessageBadge: true,
                selected: widget.selected == ElderlyNavDestination.help,
                onTap: widget.selected == ElderlyNavDestination.help
                    ? null
                    : () => _handleTap('/elderly-help', context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderlyNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showMessageBadge;

  const _ElderlyNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showMessageBadge = false,
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
              if (showMessageBadge)
                MessageUnreadBadge(
                  child: Icon(icon, size: 28, color: itemColor),
                )
              else
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
