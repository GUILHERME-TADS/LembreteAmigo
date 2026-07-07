import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/app_message.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/models/offline_write.dart';
import 'package:lembretes_app/models/smart_alert.dart';
import 'package:lembretes_app/services/supervisor_ai_service.dart';
import 'package:lembretes_app/services/offline_sync_service.dart';
import 'package:lembretes_app/services/health_service.dart';
import 'package:lembretes_app/services/session_role_service.dart';
import 'package:lembretes_app/services/smart_alert_service.dart';
import 'package:lembretes_app/utils/voice_reminder_parser.dart';
import 'package:lembretes_app/widgets/reminder_with_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mantem compatibilidade com campos antigos de conclusao', () {
    final lembrete = Lembrete.fromJson({
      'id': '1',
      'titulo': 'Tomar remedio',
      'horarioHour': 8,
      'horarioMinute': 30,
      'concluido': true,
      'concluidoComFoto': true,
      'criadoEm': DateTime(2026, 7, 1).toIso8601String(),
    });

    expect(lembrete.status, LembreteStatus.concluidoComFoto);
    expect(lembrete.concluido, isTrue);
    expect(lembrete.concluidoComFoto, isTrue);
  });

  test('usa status como fonte de verdade quando campos divergem', () {
    final pendente = Lembrete.fromJson({
      'id': '1',
      'titulo': 'Tomar remedio',
      'horarioHour': 8,
      'horarioMinute': 30,
      'status': 'pendente',
      'concluido': true,
      'concluidoComFoto': true,
      'criadoEm': DateTime(2026, 7, 1).toIso8601String(),
    });

    expect(pendente.status, LembreteStatus.pendente);
    expect(pendente.concluido, isFalse);
    expect(pendente.concluidoComFoto, isFalse);

    final concluido = Lembrete.fromJson({
      'id': '2',
      'titulo': 'Beber agua',
      'horarioHour': 9,
      'horarioMinute': 0,
      'status': 'concluido',
      'concluido': false,
      'concluidoComFoto': false,
      'criadoEm': DateTime(2026, 7, 1).toIso8601String(),
    });

    expect(concluido.status, LembreteStatus.concluido);
    expect(concluido.concluido, isTrue);
    expect(concluido.concluidoComFoto, isFalse);
  });

  test('serializa status e recorrencia semanal', () {
    final lembrete = Lembrete(
      id: '2',
      titulo: 'Caminhar',
      horarioHour: 9,
      horarioMinute: 0,
      categoria: 'exercicio',
      status: LembreteStatus.adiado,
      recorrencia: 'semanal',
      diasSemana: const [1, 3, 5],
    );

    final json = lembrete.toJson();
    expect(json['status'], 'adiado');
    expect(json['concluido'], isFalse);
    expect(json['recorrencia'], 'semanal');
    expect(json['diasSemana'], [1, 3, 5]);
  });

  test('copyWith preserva dados e altera apenas o status pedido', () {
    final lembrete = Lembrete(
      id: '3',
      titulo: 'Beber agua',
      horarioHour: 10,
      horarioMinute: 15,
    );

    final atualizado = lembrete.copyWith(status: LembreteStatus.concluido);

    expect(atualizado.id, lembrete.id);
    expect(atualizado.titulo, lembrete.titulo);
    expect(atualizado.status, LembreteStatus.concluido);
    expect(atualizado.concluido, isTrue);
  });

  test('copyWith sincroniza booleanos de conclusao com status', () {
    final lembrete = Lembrete(
      id: '3',
      titulo: 'Beber agua',
      horarioHour: 10,
      horarioMinute: 15,
    );

    final concluido = lembrete.copyWith(concluido: true);
    expect(concluido.status, LembreteStatus.concluido);
    expect(concluido.concluido, isTrue);

    final pendente = concluido.copyWith(concluido: false);
    expect(pendente.status, LembreteStatus.pendente);
    expect(pendente.concluido, isFalse);
    expect(pendente.concluidoComFoto, isFalse);
  });

  test('mapeia status para marcacao visual dos cards', () {
    Lembrete lembreteComStatus(LembreteStatus status) => Lembrete(
      id: '1',
      titulo: 'Tomar agua',
      horarioHour: 9,
      horarioMinute: 0,
      status: status,
    );

    expect(
      reminderStatusFromLembrete(lembreteComStatus(LembreteStatus.pendente)),
      ReminderStatus.scheduled,
    );
    expect(
      reminderStatusFromLembrete(lembreteComStatus(LembreteStatus.adiado)),
      ReminderStatus.postponed,
    );
    expect(
      reminderStatusFromLembrete(lembreteComStatus(LembreteStatus.perdido)),
      ReminderStatus.missed,
    );
    expect(
      reminderStatusFromLembrete(lembreteComStatus(LembreteStatus.concluido)),
      ReminderStatus.done,
    );
    expect(
      reminderStatusFromLembrete(
        lembreteComStatus(LembreteStatus.concluidoComFoto),
      ),
      ReminderStatus.done,
    );
  });

  test('mapeia lembrete pendente atrasado para alerta visual', () {
    final lembrete = Lembrete(
      id: '1',
      titulo: 'Tomar agua',
      horarioHour: 9,
      horarioMinute: 0,
      criadoEm: DateTime(2026, 7, 2, 8),
    );

    expect(
      reminderVisualStatusFromLembrete(
        lembrete,
        now: DateTime(2026, 7, 2, 9, 10),
      ),
      ReminderStatus.late,
    );
  });

  test('nao sobrescreve status salvo ao calcular alerta visual', () {
    Lembrete lembreteComStatus(LembreteStatus status) => Lembrete(
      id: status.storageValue,
      titulo: 'Tomar agua',
      horarioHour: 9,
      horarioMinute: 0,
      criadoEm: DateTime(2026, 7, 2, 8),
      status: status,
    );

    expect(
      reminderVisualStatusFromLembrete(
        lembreteComStatus(LembreteStatus.adiado),
        now: DateTime(2026, 7, 2, 9, 10),
      ),
      ReminderStatus.postponed,
    );
    expect(
      reminderVisualStatusFromLembrete(
        lembreteComStatus(LembreteStatus.perdido),
        now: DateTime(2026, 7, 2, 9, 10),
      ),
      ReminderStatus.missed,
    );
    expect(
      reminderVisualStatusFromLembrete(
        lembreteComStatus(LembreteStatus.concluido),
        now: DateTime(2026, 7, 2, 9, 10),
      ),
      ReminderStatus.done,
    );
  });

  test('gera alerta inteligente para medicamento atrasado', () {
    final service = SmartAlertService.instance;
    final now = DateTime(2026, 7, 2, 9, 20);
    final lembrete = Lembrete(
      id: 'med-1',
      titulo: 'Losartana',
      horarioHour: 9,
      horarioMinute: 0,
      categoria: 'medicacao',
    );

    final alerts = service.detectarAlertas([lembrete], now: now);

    expect(alerts, hasLength(1));
    expect(alerts.first.severity, SmartAlertSeverity.warning);
    expect(alerts.first.message, contains('Losartana'));
  });

  test('nao alerta lembrete comum antes da tolerancia', () {
    final service = SmartAlertService.instance;
    final now = DateTime(2026, 7, 2, 9, 20);
    final lembrete = Lembrete(
      id: 'custom-1',
      titulo: 'Telefonar',
      horarioHour: 9,
      horarioMinute: 0,
      categoria: 'personalizado',
    );

    final alerts = service.detectarAlertas([lembrete], now: now);

    expect(alerts, isEmpty);
  });

  test('alerta critico aparece em primeiro lugar', () {
    final service = SmartAlertService.instance;
    final now = DateTime(2026, 7, 2, 9, 10);
    final normal = Lembrete(
      id: 'normal-1',
      titulo: 'Alongar',
      horarioHour: 8,
      horarioMinute: 0,
      categoria: 'exercicio',
    );
    final critico = Lembrete(
      id: 'crit-1',
      titulo: 'Insulina',
      horarioHour: 9,
      horarioMinute: 7,
      categoria: 'medicacao',
      urgencia: 'critico',
    );

    final alerts = service.detectarAlertas([normal, critico], now: now);

    expect(alerts.first.lembreteId, 'crit-1');
    expect(alerts.first.severity, SmartAlertSeverity.critical);
  });

  test('nao gera alerta para lembrete concluido', () {
    final service = SmartAlertService.instance;
    final now = DateTime(2026, 7, 2, 10, 0);
    final lembrete = Lembrete(
      id: 'done-1',
      titulo: 'Agua',
      horarioHour: 8,
      horarioMinute: 0,
      status: LembreteStatus.concluido,
    );

    final alerts = service.detectarAlertas([lembrete], now: now);

    expect(alerts, isEmpty);
  });

  test('gera alerta para bpm fora da faixa de repouso usada pelo app', () {
    final service = SmartAlertService.instance;
    final now = DateTime(2026, 7, 2, 10, 0);

    final alerts = service.detectarAlertas(const [], now: now, bpm: 124);

    expect(alerts, hasLength(1));
    expect(alerts.first.lembreteId, isEmpty);
    expect(alerts.first.severity, SmartAlertSeverity.critical);
    expect(alerts.first.message, contains('124 BPM'));
  });

  test('valida bpm antes de salvar metricas de saude', () {
    expect(HealthService.isValidBpm(39), isFalse);
    expect(HealthService.isValidBpm(40), isTrue);
    expect(HealthService.isValidBpm(72), isTrue);
    expect(HealthService.isValidBpm(180), isTrue);
    expect(HealthService.isValidBpm(181), isFalse);
    expect(HealthService.isValidBpm(null), isFalse);
  });

  test(
    'nao gera alerta para bpm dentro da faixa de repouso usada pelo app',
    () {
      final service = SmartAlertService.instance;
      final now = DateTime(2026, 7, 2, 10, 0);

      final alerts = service.detectarAlertas(const [], now: now, bpm: 78);

      expect(alerts, isEmpty);
    },
  );

  test('serializa escrita offline pendente', () {
    final write = OfflineWrite(
      id: 'w1',
      collection: 'lembretes',
      docId: 'abc',
      action: OfflineWriteAction.update,
      data: const {'status': 'concluido'},
      createdAt: DateTime(2026, 7, 2, 10),
      attempts: 2,
    );

    final restored = OfflineWrite.fromJson(write.toJson());

    expect(restored.id, 'w1');
    expect(restored.collection, 'lembretes');
    expect(restored.docId, 'abc');
    expect(restored.action, OfflineWriteAction.update);
    expect(restored.data['status'], 'concluido');
    expect(restored.attempts, 2);
  });

  test('serializa mensagem de texto entre cuidador e idoso', () {
    final message = AppMessage(
      id: 'msg-1',
      idosoId: 'idoso-1',
      nomeIdoso: 'Maria',
      senderRole: 'supervisor',
      tipo: 'texto',
      texto: 'Tudo bem por ai?',
      criadoEm: DateTime(2026, 7, 3, 9, 30),
    );

    final restored = AppMessage.fromJson(message.toJson());

    expect(restored.id, 'msg-1');
    expect(restored.senderRole, 'supervisor');
    expect(restored.texto, 'Tudo bem por ai?');
    expect(restored.nomeIdoso, 'Maria');
  });

  test('seleciona idoso ativo de acordo com o papel da sessao', () async {
    SharedPreferences.setMockInitialValues({
      'selected_idoso_id': 'idoso_supervisor',
      'paired_idoso_id': 'idoso_pareado',
    });

    await SessionRoleService.setSupervisor();
    expect(await SessionRoleService.getActiveIdosoId(), 'idoso_supervisor');

    await SessionRoleService.setElderly();
    expect(await SessionRoleService.getActiveIdosoId(), 'idoso_pareado');
  });

  test(
    'enfileira escrita offline quando firebase nao esta disponivel',
    () async {
      SharedPreferences.setMockInitialValues({});

      await OfflineSyncService.instance.enqueue(
        collection: 'mensagens',
        docId: 'msg-1',
        action: OfflineWriteAction.set,
        data: const {'texto': 'oi'},
      );

      final queue = await OfflineSyncService.instance.loadQueue();

      expect(queue, hasLength(1));
      expect(queue.first.collection, 'mensagens');
      expect(queue.first.data['texto'], 'oi');
    },
  );

  group('parser de lembrete por voz', () {
    void expectTime(String phrase, int hour, int minute) {
      final parsed = VoiceReminderParser.parse(phrase);
      expect(parsed, isNotNull, reason: phrase);
      expect(parsed!.hour, hour, reason: phrase);
      expect(parsed.minute, minute, reason: phrase);
    }

    test('entende horas, minutos e turnos comuns', () {
      expectTime('Tomar remedio as oito e cinco da manha', 8, 5);
      expectTime('Tomar remedio as duas da tarde', 14, 0);
      expectTime('Beber agua as oito da noite', 20, 0);
      expectTime('Medir pressao as doze da noite', 0, 0);
      expectTime('Caminhar as doze da tarde', 12, 0);
    });

    test('entende frases com acentos reais', () {
      expectTime('Tomar remédio às oito e cinco da manhã', 8, 5);
      expectTime('Beber água às oito da noite', 20, 0);
      expectTime('Medir pressão às doze da noite', 0, 0);
    });

    test('entende meia, meio-dia e meia-noite com minutos', () {
      expectTime('Almocar meio-dia e meia', 12, 30);
      expectTime('Tomar remedio meia-noite e quinze', 0, 15);
      expectTime('Tomar cha as oito e meia', 8, 30);
    });

    test('entende frases relativas como para as e menos', () {
      expectTime('Tomar remedio cinco para as oito da noite', 19, 55);
      expectTime('Tomar remedio quinze pras duas da tarde', 13, 45);
      expectTime('Medir glicose dez para as seis da manha', 5, 50);
      expectTime('Tomar agua oito menos cinco da noite', 19, 55);
    });
  });

  group('isActiveOn (recorrencia centralizada)', () {
    test('diario retorna true para qualquer data', () {
      final l = Lembrete(id: '1', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'diario');
      expect(l.isActiveOn(DateTime(2026, 7, 1)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 15)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 12, 31)), isTrue);
    });

    test('semanal retorna true apenas nos dias corretos', () {
      final monday = DateTime(2026, 7, 6);
      expect(monday.weekday, 1);
      final l = Lembrete(id: '2', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'semanal', diasSemana: const [1, 3, 5], repeteTodosOsDias: false);
      expect(l.isActiveOn(monday), isTrue);
      expect(l.isActiveOn(monday.add(const Duration(days: 2))), isTrue);  // Wednesday
      expect(l.isActiveOn(monday.add(const Duration(days: 4))), isTrue);  // Friday
      expect(l.isActiveOn(monday.add(const Duration(days: 1))), isFalse); // Tuesday
      expect(l.isActiveOn(monday.add(const Duration(days: 5))), isFalse); // Saturday
    });

    test('mensal retorna true no dia correspondente', () {
      final l = Lembrete(id: '3', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'mensal', diaMes: 15, criadoEm: DateTime(2026, 1, 1), repeteTodosOsDias: false);
      expect(l.isActiveOn(DateTime(2026, 7, 15)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 8, 15)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 14)), isFalse);
    });

    test('unico retorna true apenas na data de criacao', () {
      final l = Lembrete(id: '4', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'unico', criadoEm: DateTime(2026, 7, 4), repeteTodosOsDias: false);
      expect(l.isActiveOn(DateTime(2026, 7, 4)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 5)), isFalse);
    });

    test('quinzenal segue ciclo de 15 dias', () {
      final l = Lembrete(id: '5', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'quinzenal', criadoEm: DateTime(2026, 7, 1), repeteTodosOsDias: false);
      expect(l.isActiveOn(DateTime(2026, 7, 1)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 16)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 31)), isTrue);
      expect(l.isActiveOn(DateTime(2026, 7, 10)), isFalse);
    });
  });

  group('SupervisorInsights', () {
    test('hasContent retorna true quando tem conteudo', () {
      expect(const SupervisorInsights(summary: '').hasContent, isFalse);
      expect(const SupervisorInsights(summary: 'Resumo').hasContent, isTrue);
      expect(const SupervisorInsights(summary: '', insights: ['ok']).hasContent, isTrue);
    });
  });

  group('HealthService BPM', () {
    test('bpmHistory comeca vazio', () {
      expect(HealthService.instance.bpmHistory, isEmpty);
    });

    test('bpmStream e um broadcast stream', () {
      final stream = HealthService.instance.bpmStream;
      expect(stream, isNotNull);
      expect(stream.isBroadcast, isTrue);
    });
  });

  group('Lembrete isReminderActiveOn estatico', () {
    test('chamada estatica produz mesmo resultado que instancia', () {
      final l = Lembrete(id: '1', titulo: 'Teste', horarioHour: 8, horarioMinute: 0, recorrencia: 'semanal', diasSemana: const [3], repeteTodosOsDias: false);
      final date = DateTime(2026, 7, 8);
      expect(l.isActiveOn(date), isTrue);
      expect(Lembrete.isReminderActiveOn(l, date), isTrue);
    });
  });
}
