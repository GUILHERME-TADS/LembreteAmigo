import 'dart:io';

import 'package:flutter/foundation.dart';

/// Serviço higiênico para limpeza automática de caches temporários de áudio, imagens e pré-visualizações.
class CacheJanitorService {
  CacheJanitorService._();
  static final CacheJanitorService instance = CacheJanitorService._();

  /// Executa uma varredura silenciosa e descarta arquivos temporários mais antigos que [maxAge].
  /// Retorna a quantidade de arquivos removidos.
  Future<int> cleanExpiredCaches({
    Duration maxAge = const Duration(days: 14),
    List<Directory>? customDirectories,
  }) async {
    if (kIsWeb) return 0;
    int deletedCount = 0;
    final now = DateTime.now();

    final targetDirs = <Directory>[];
    if (customDirectories != null) {
      targetDirs.addAll(customDirectories);
    } else {
      try {
        final tempDir = Directory.systemTemp;
        if (await tempDir.exists()) {
          targetDirs.add(tempDir);
        }
      } catch (e) {
        debugPrint('[CacheJanitor] Erro ao acessar diretório temporário: $e');
      }
    }

    for (final dir in targetDirs) {
      try {
        if (!await dir.exists()) continue;
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last.toLowerCase();
            // Limpa apenas arquivos temporários do app (áudios, thumbnails, logs temporários)
            final isAppTempFile = fileName.startsWith('cache_') ||
                fileName.startsWith('temp_') ||
                fileName.startsWith('audio_') ||
                fileName.endsWith('.tmp') ||
                fileName.endsWith('.pcm');

            if (isAppTempFile) {
              final stat = await entity.stat();
              if (now.difference(stat.modified) > maxAge) {
                try {
                  await entity.delete();
                  deletedCount++;
                } catch (e) {
                  debugPrint('[CacheJanitor] Falha ao deletar ${entity.path}: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[CacheJanitor] Erro durante a varredura do diretório ${dir.path}: $e');
      }
    }

    if (deletedCount > 0) {
      debugPrint('[CacheJanitor] Limpeza concluída: $deletedCount arquivos antigos removidos.');
    }
    return deletedCount;
  }

  /// Calcula o tamanho em bytes de arquivos temporários no diretório informado.
  Future<int> calculateDirectorySizeBytes(Directory directory) async {
    if (!await directory.exists()) return 0;
    int totalBytes = 0;
    try {
      final entities = directory.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('[CacheJanitor] Erro ao calcular tamanho: $e');
    }
    return totalBytes;
  }
}
