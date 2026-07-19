// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> fetchBlobBytes(String blobUrl) async {
  final completer = Completer<Uint8List?>();
  final xhr = html.HttpRequest();
  xhr.open('GET', blobUrl);
  xhr.responseType = 'arraybuffer';
  xhr.onLoad.listen((e) {
    if (xhr.status == 200) {
      final buffer = xhr.response as ByteBuffer;
      completer.complete(buffer.asUint8List());
    } else {
      completer.complete(null);
    }
  });
  xhr.onError.listen((e) {
    completer.complete(null);
  });
  xhr.send();
  return completer.future;
}
