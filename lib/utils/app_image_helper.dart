import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utilitário centralizado para otimização de renderização e decodificação de imagens em memória.
/// 
/// Evita decodificar imagens em resolução total nativa (ex: 12MP/4K da câmera),
/// o que economiza até 80-90% de consumo de memória RAM e previne travamentos (OOM).
class AppImageHelper {
  AppImageHelper._();

  /// Largura e altura padrão máximas para miniaturas e avatares.
  static const int defaultThumbnailSize = 300;

  /// Largura e altura padrão máximas para exibição em tela cheia/cards médios.
  static const int defaultDisplaySize = 800;

  /// Retorna um [ImageProvider] de arquivo redimensionado em tempo de decodificação.
  static ImageProvider resizedFileImage(
    File file, {
    int? maxWidth = defaultDisplaySize,
    int? maxHeight = defaultDisplaySize,
  }) {
    final imageProvider = FileImage(file);
    if (kIsWeb) {
      return imageProvider;
    }
    return ResizeImage.resizeIfNeeded(
      maxWidth,
      maxHeight,
      imageProvider,
    );
  }

  /// Retorna um [ImageProvider] com tamanho para avatar/miniatura.
  static ImageProvider thumbnailFileImage(
    File file, {
    int size = defaultThumbnailSize,
  }) {
    return resizedFileImage(file, maxWidth: size, maxHeight: size);
  }

  /// Widget facilitador para renderizar imagens de arquivo com cache dimensionado.
  static Widget buildFileImage({
    required File file,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    int? cacheWidth = defaultDisplaySize,
    int? cacheHeight = defaultDisplaySize,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: kIsWeb ? null : cacheWidth,
      cacheHeight: kIsWeb ? null : cacheHeight,
      errorBuilder: errorBuilder ??
          (context, error, stackTrace) => Container(
                width: width,
                height: height,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
              ),
    );
  }
}
