import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

bool isRemoteAudioPath(String path) {
  return isRemotePath(path);
}

bool isRemotePath(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

Future<bool> audioPathExists(String path) async {
  if (path.isEmpty) return false;
  if (isRemoteAudioPath(path)) return true;
  return File(path).exists();
}

Source audioSourceForPath(String path) {
  return isRemoteAudioPath(path) ? UrlSource(path) : DeviceFileSource(path);
}
