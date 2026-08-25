import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/services/secure_cache_service.dart';

void main() {
  group('SecureCacheService safeJsonEncode Tests', () {
    test('serializa mapa com Timestamp do Firestore sem lancar erro', () {
      final now = DateTime(2026, 8, 19, 22, 0, 0);
      final timestamp = Timestamp.fromDate(now);

      final map = {
        'nome': 'Dona Maria',
        'createdAt': timestamp,
        'updatedAt': now,
        'nested': {
          'lastSeen': timestamp,
        },
      };

      final jsonResult = SecureCacheService.safeJsonEncode(map);
      expect(jsonResult, contains('Dona Maria'));
      expect(jsonResult, contains('2026-08-19T22:00:00.000'));
    });

    test('serializa tipos primitivos normalmente', () {
      final map = {
        'id': '123',
        'ativo': true,
        'idade': 80,
      };

      final jsonResult = SecureCacheService.safeJsonEncode(map);
      expect(jsonResult, '{"id":"123","ativo":true,"idade":80}');
    });
  });
}
