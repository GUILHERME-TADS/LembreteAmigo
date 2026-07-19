import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SupervisorHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const SupervisorHeader({
    super.key,
    this.title = 'Cuidador',
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: 32,
          ),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.health_and_safety,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}
