import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showMenu = false,
    this.horizontalPadding = 20,
    this.iconSize = 32,
  });

  final String title;
  final bool showMenu;
  final double horizontalPadding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (showMenu) {
                Scaffold.of(context).openDrawer();
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(
              showMenu ? Icons.menu : Icons.arrow_back,
              color: AppColors.primary,
              size: iconSize,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
