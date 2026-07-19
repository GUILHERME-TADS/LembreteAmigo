import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class RemoteMediaCacheService {
  RemoteMediaCacheService._();
  static final RemoteMediaCacheService instance =
      RemoteMediaCacheService._();

  static const int maxCacheBytes = 200 * 1024 * 1024;
  final Map<String, Future<String>> _downloads = {};

  bool _isRemote(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<String> resolve(String? path) async {
    if (path == null || path.isEmpty || !_isRemote(path) || kIsWeb) {
      return path ?? '';
    }
    return _downloads.putIfAbsent(path, () => _download(path)).whenComplete(
      () => _downloads.remove(path),
    );
  }

  Future<String> _download(String url) async {
    final directory = await _cacheDirectory();
    final target = File('${directory.path}/${_fileName(url)}');
    if (await target.exists() && await target.length() > 0) {
      await target.setLastModified(DateTime.now());
      return target.path;
    }

    final temporary = File('${target.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final sink = temporary.openWrite();
      try {
        await response.pipe(sink).timeout(const Duration(seconds: 30));
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (await temporary.length() == 0) {
        throw const FileSystemException('A mídia recebida está vazia.');
      }
      await temporary.rename(target.path);
      unawaited(_trimCache(directory));
      return target.path;
    } catch (error) {
      if (await temporary.exists()) await temporary.delete();
      debugPrint('Não foi possível armazenar mídia para uso offline: $error');
      return url;
    } finally {
      client.close(force: true);
    }
  }

  Future<Directory> _cacheDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/received_media_cache');
    await directory.create(recursive: true);
    return directory;
  }

  String _fileName(String url) {
    int hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final hashString = hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final decoded = Uri.decodeFull(url).toLowerCase();
    const extensions = ['.m4a', '.mp3', '.wav', '.aac', '.ogg', '.jpg', '.jpeg', '.png', '.webp'];
    final extension = extensions.firstWhere(
      decoded.contains,
      orElse: () => '.bin',
    );
    return '$hashString$extension';
  }

  Future<void> _trimCache(Directory directory) async {
    final files = await directory
        .list()
        .where((entity) => entity is File && !entity.path.endsWith('.part'))
        .cast<File>()
        .toList();
    final entries = <({File file, int size, DateTime used})>[];
    var total = 0;
    for (final file in files) {
      try {
        final stat = await file.stat();
        total += stat.size;
        entries.add((file: file, size: stat.size, used: stat.modified));
      } catch (_) {}
    }
    if (total <= maxCacheBytes) return;
    entries.sort((a, b) => a.used.compareTo(b.used));
    for (final entry in entries) {
      if (total <= maxCacheBytes) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (_) {}
    }
  }
}
