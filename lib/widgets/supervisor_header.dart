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
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: 32,
          ),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.health_and_safety,
                size: 36,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}
