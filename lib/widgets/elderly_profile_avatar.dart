import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/remote_media_cache_service.dart';
import '../theme/app_theme.dart';

import '../utils/app_image_helper.dart';

class ElderlyProfileAvatar extends StatefulWidget {
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
  State<ElderlyProfileAvatar> createState() => _ElderlyProfileAvatarState();
}

class _ElderlyProfileAvatarState extends State<ElderlyProfileAvatar> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolvedPath = widget.fotoPath;
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant ElderlyProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoPath != widget.fotoPath) {
      _resolvedPath = widget.fotoPath;
      _resolvePhoto();
    }
  }

  Future<void> _resolvePhoto() async {
    final original = widget.fotoPath;
    final resolved = await RemoteMediaCacheService.instance.resolve(original);
    if (!mounted || original != widget.fotoPath || resolved == original) return;
    setState(() => _resolvedPath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final fotoPath = _resolvedPath;
    final showLocalImage =
        fotoPath != null &&
        !fotoPath.startsWith('avatar_') &&
        !fotoPath.startsWith('http') &&
        !kIsWeb &&
        File(fotoPath).existsSync();

    final showNetworkImage = fotoPath != null && fotoPath.startsWith('http');
    final pixelSize = (widget.size * 2).toInt();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer,
        border: Border.all(
          color: AppColors.primaryContainer,
          width: widget.borderWidth,
        ),
        image: showLocalImage
            ? DecorationImage(
                image: AppImageHelper.thumbnailFileImage(
                  File(fotoPath),
                  size: pixelSize,
                ),
                fit: BoxFit.cover,
              )
            : showNetworkImage
            ? DecorationImage(
                image: ResizeImage.resizeIfNeeded(
                  pixelSize,
                  pixelSize,
                  NetworkImage(fotoPath),
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !showLocalImage && !showNetworkImage
          ? Icon(Icons.person, color: Colors.white, size: widget.size * 0.58)
          : null,
    );
  }
}
