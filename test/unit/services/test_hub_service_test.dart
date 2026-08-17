import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/services/lembrete_service.dart';
import 'package:lembretes_app/services/session_role_service.dart';
import 'package:lembretes_app/services/test_hub_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'active_role': 'elderly',
      'selected_idoso_id': 'idoso_local',
      'paired_idoso_id': 'idoso_local',
    });
    await SessionRoleService.setElderly();
    await LembreteService.instance.reset();
  });

  tearDown(() async {
    await TestHubService.instance.clearMockData();
  });

  group('TestHubService', () {
    test('instance retorna singleton não nulo', () {
      expect(TestHubService.instance, isNotNull);
    });

    test('generateMockAdherenceData gera lembretes e eventos simulados', () async {
      final generatedCount = await TestHubService.instance.generateMockAdherenceData();
      
      expect(generatedCount, greaterThan(0));
      expect(TestHubService.instance.hasMockData(), isTrue);

      final lembretes = LembreteService.instance.lembretes;
      expect(
        lembretes.any((l) => l.id.startsWith(TestHubService.mockPrefix)),
        isTrue,
      );
    });

    test('clearMockData limpa todos os lembretes e eventos gerados pelo sandbox', () async {
      await TestHubService.instance.generateMockAdherenceData();
      expect(TestHubService.instance.hasMockData(), isTrue);

      final removedCount = await TestHubService.instance.clearMockData();
      expect(removedCount, greaterThan(0));
      expect(TestHubService.instance.hasMockData(), isFalse);

      final lembretes = LembreteService.instance.lembretes;
      expect(
        lembretes.any((l) => l.id.startsWith(TestHubService.mockPrefix)),
        isFalse,
      );
    });

    test('hasMockData identifica lembretes de teste isolados', () async {
      expect(TestHubService.instance.hasMockData(), isFalse);

      final testReminder = Lembrete(
        id: TestHubService.testReminderId,
        titulo: 'Teste Rápido',
        horarioHour: 10,
        horarioMinute: 0,
      );

      await LembreteService.instance.adicionar(testReminder);
      expect(TestHubService.instance.hasMockData(), isTrue);

      await TestHubService.instance.clearMockData();
      expect(TestHubService.instance.hasMockData(), isFalse);
    });
  });
}
