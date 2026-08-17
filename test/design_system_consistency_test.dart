import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screens = Directory('lib/screens')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('todas as telas dependem do tema central', () {
    expect(screens.length, greaterThanOrEqualTo(48));
    final missing = screens
        .where((file) => !file.readAsStringSync().contains('app_theme.dart'))
        .map((file) => file.path)
        .toList();
    expect(missing, isEmpty, reason: 'Telas sem tema central: $missing');
  });

  test('nao existem paletas Material paralelas nas telas', () {
    final legacyColor = RegExp(
      r'\bColors\.(green|red|yellow|orange|amber|blue|indigo|purple|teal|grey|brown)',
    );
    final offenders = <String>[];
    for (final file in screens) {
      if (file.path.contains('practice_mode_screen')) continue;
      if (legacyColor.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: 'Cores fora do tema: $offenders');
  });

  test('todas as cores de tela passam pelo tema central', () {
    final offenders = <String>[];
    for (final file in screens) {
      final source = file.readAsStringSync();
      if (!source.contains('Color(0x')) continue;
      offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: 'Cores fixas fora do tema: $offenders');
  });
}
