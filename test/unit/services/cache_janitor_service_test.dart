import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/cache_janitor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheJanitorService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_janitor_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('calcula tamanho de diretório vazio como 0 bytes', () async {
      final size = await CacheJanitorService.instance.calculateDirectorySizeBytes(tempDir);
      expect(size, 0);
    });

    test('calcula tamanho correto de arquivos temporários', () async {
      final file1 = File('${tempDir.path}/temp_test1.tmp');
      await file1.writeAsBytes(List.filled(1024, 0)); // 1KB

      final file2 = File('${tempDir.path}/audio_cache.aac');
      await file2.writeAsBytes(List.filled(2048, 0)); // 2KB

      final size = await CacheJanitorService.instance.calculateDirectorySizeBytes(tempDir);
      expect(size, 3072);
    });

    test('limpa arquivos temporários expirados e preserva arquivos recentes', () async {
      final oldFile = File('${tempDir.path}/temp_old.tmp');
      await oldFile.writeAsString('dados antigos');
      // Altera a data de modificação para 20 dias atrás
      final twentyDaysAgo = DateTime.now().subtract(const Duration(days: 20));
      await oldFile.setLastModified(twentyDaysAgo);

      final recentFile = File('${tempDir.path}/temp_recent.tmp');
      await recentFile.writeAsString('dados recentes');

      final deleted = await CacheJanitorService.instance.cleanExpiredCaches(
        maxAge: const Duration(days: 14),
        customDirectories: [tempDir],
      );

      expect(deleted, 1);
      expect(await oldFile.exists(), isFalse);
      expect(await recentFile.exists(), isTrue);
    });
  });
}
