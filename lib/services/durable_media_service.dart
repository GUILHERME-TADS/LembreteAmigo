import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DurableMediaService {
  DurableMediaService._();
  static final DurableMediaService instance = DurableMediaService._();

  Future<String> preserve(String path, {required String prefix}) async {
    if (kIsWeb ||
        path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('assets/')) {
      return path;
    }

    final source = File(path);
    if (!await source.exists()) return path;

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/pending_media');
    await directory.create(recursive: true);
    final normalizedDirectory = directory.absolute.path.toLowerCase();
    if (source.absolute.path.toLowerCase().startsWith(normalizedDirectory)) {
      return source.path;
    }

    final dot = path.lastIndexOf('.');
    final extension = dot >= 0 ? path.substring(dot) : '';
    final filename =
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final target = File('${directory.path}/$filename');
    await source.copy(target.path);
    return target.path;
  }
}
