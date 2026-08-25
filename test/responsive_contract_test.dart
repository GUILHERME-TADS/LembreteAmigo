import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every screen has a vertical overflow strategy', () {
    final screens = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    final uncovered = <String>[];
    final scrollPattern = RegExp(
      r'SingleChildScrollView|ListView|GridView|CustomScrollView|ResponsiveScrollView',
    );

    for (final screen in screens) {
      final source = screen.readAsStringSync();
      if (!scrollPattern.hasMatch(source)) {
        uncovered.add(screen.uri.pathSegments.last);
      }
    }

    // The camera intentionally keeps a fixed viewport.
    expect(uncovered..sort(), [
      'take_photo_confirmation_screen.dart',
    ]);
    final cameraSource = File(
      'lib/screens/take_photo_confirmation_screen.dart',
    ).readAsStringSync();
    expect(cameraSource, contains('context.isCompactHeight'));
    expect(cameraSource, contains('panelHeight'));
  });
}
