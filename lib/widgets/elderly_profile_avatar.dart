import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ElderlyProfileAvatar extends StatelessWidget {
  final String? fotoPath;
  final double size;
  final double borderWidth;

  const ElderlyProfileAvatar({
    super.key,
    required this.fotoPath,
    this.size = 48,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final showLocalImage = fotoPath != null &&
        !fotoPath!.startsWith('avatar_') &&
        !fotoPath!.startsWith('http') &&
        File(fotoPath!).existsSync();

    final showNetworkImage = fotoPath != null && fotoPath!.startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer,
        border: Border.all(color: AppColors.primaryContainer, width: borderWidth),
        image: showLocalImage
            ? DecorationImage(
                image: FileImage(File(fotoPath!)),
                fit: BoxFit.cover,
              )
            : showNetworkImage
                ? DecorationImage(
                    image: NetworkImage(fotoPath!),
                    fit: BoxFit.cover,
                  )
                : null,
      ),
      child: !showLocalImage && !showNetworkImage
          ? Icon(
              Icons.person,
              color: Colors.white,
              size: size * 0.58,
            )
          : null,
    );
  }
}
