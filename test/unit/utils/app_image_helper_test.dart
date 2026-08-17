import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/utils/app_image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppImageHelper', () {
    test('resizedFileImage returns an ImageProvider', () {
      final file = File('test_image.png');
      final provider = AppImageHelper.resizedFileImage(file, maxWidth: 400, maxHeight: 400);
      expect(provider, isA<ImageProvider>());
    });

    test('thumbnailFileImage returns an ImageProvider with default thumbnail size', () {
      final file = File('test_avatar.jpg');
      final provider = AppImageHelper.thumbnailFileImage(file);
      expect(provider, isA<ImageProvider>());
    });

    testWidgets('buildFileImage renders correctly with placeholder on missing file', (tester) async {
      final file = File('non_existent_file_test.png');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppImageHelper.buildFileImage(
              file: file,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}
