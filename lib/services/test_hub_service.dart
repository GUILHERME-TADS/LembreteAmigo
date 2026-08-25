import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../services/vibration_service.dart';

class TestHubService {
  TestHubService._();
  static final TestHubService instance = TestHubService._();

  static const String testReminderId = 'test_hub_alarm_quick';
  static const String testPhotoReminderId = 'test_hub_alarm_photo';
  static const String mockPrefix = 'mock_demo_';

  /// Dispara alarme de teste em tempo de execução
  Future<void> simulateAlarmNow({
    bool requirePhoto = false,
    String? customTitle,
  }) async {
    final now = DateTime.now();
    final id = requirePhoto ? testPhotoReminderId : testReminderId;
    final title = customTitle ??
        (requirePhoto
            ? 'Remédio com Foto (Teste)'
            : 'Losartana 50mg (Teste de Alarme)');

    final testReminder = Lembrete(
      id: id,
      titulo: title,
      horarioHour: now.hour,
      horarioMinute: now.minute,
      categoria: LembreteCategoria.medicacao,
      prioridade: LembretePrioridade.critica,
      modoConfirmacao: requirePhoto
          ? LembreteModoConfirmacao.foto
          : LembreteModoConfirmacao.simples,
      medicamentoInstrucoes: requirePhoto
          ? 'Tire uma foto nítida da cartela de remédio.'
          : 'Tomar 1 comprimido com meio copo de água.',
      medicamentoDose: '1 comprimido',
      medicamentoEstoque: 28,
      medicamentoEstoqueMinimo: 5,
      repeteTodosOsDias: true,
      avisarCuidador: true,
      concluido: false,
    );

    await LembreteService.instance.adicionar(testReminder);

    // Feedback sonoro e tátil
    unawaited(VibrationService.attentionPattern());
    unawaited(
      TTSService.instance.falar(
        'Atenção! Este é um teste de disparo de alarme do Lembrete Amigo. $title.',
      ),
    );

    // Navega para a tela de alarme ativo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamed('/active-reminder', arguments: testReminder.id);
      }
    });
  }

  /// Simula alerta de emergência do idoso
  Future<void> simulateEmergencySOS() async {
    unawaited(VibrationService.attentionPattern());
    unawaited(
      TTSService.instance.falar(
        'Atenção! Simulação de pedido de socorro e alerta de emergência.',
      ),
    );

    final now = DateTime.now();
    final sosReminder = Lembrete(
      id: 'test_hub_emergency_reminder',
      titulo: 'Pedido de Ajuda do Idoso (Simulado)',
      horarioHour: now.hour,
      horarioMinute: now.minute,
      categoria: LembreteCategoria.medicacao,
      prioridade: LembretePrioridade.critica,
      status: LembreteStatus.precisaDeAjuda,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamed(
          '/emergency-alert',
          arguments: {
            'lembrete': sosReminder,
            'totalAlertas': 1,
          },
        );
      }
    });
  }

  /// Simula chamada de vídeo recebida
  Future<void> simulateIncomingVideoCall({
    String callerName = 'Dra. Ana (Cuidadora)',
    String callType = 'video',
  }) async {
    unawaited(VibrationService.gentleFeedback());
    unawaited(
      TTSService.instance.falar(
        'Chamada de vídeo simulada recebida de $callerName.',
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamed(
          '/incoming-video-call',
          arguments: {
            'callId': 'test_call_${DateTime.now().millisecondsSinceEpoch}',
            'roomName': 'sala_teste_lembrete_amigo',
            'callType': callType,
          },
        );
      }
    });
  }

  /// Testa padrões de vibração
  Future<void> testVibration(String type) async {
    switch (type) {
      case 'suave':
        await VibrationService.gentleFeedback();
        break;
      case 'sucesso':
        await VibrationService.successPattern();
        break;
      case 'aviso':
      case 'emergencia':
      default:
        await VibrationService.attentionPattern();
        break;
    }
  }

  /// Testa reprodução de áudio e voz
  Future<void> testAudioVoice({
    String message = 'Olá! O sistema de voz do Lembrete Amigo está funcionando perfeitamente.',
  }) async {
    await TTSService.instance.parar();
    await TTSService.instance.falar(message);
  }

  /// Gera histórico realista de 7 dias para testar relatórios e dashboard
  Future<int> generateMockAdherenceData() async {
    final now = DateTime.now();
    final idosoId = await SessionRoleService.getActiveIdosoId();

    final mockReminders = [
      Lembrete(
        id: '${mockPrefix}losartana',
        titulo: 'Losartana 50mg (Manhã)',
        horarioHour: 8,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
        prioridade: LembretePrioridade.critica,
        modoConfirmacao: LembreteModoConfirmacao.simples,
        medicamentoDose: '1 comprimido',
        medicamentoEstoque: 24,
        medicamentoEstoqueMinimo: 6,
        idosoId: idosoId,
        repeteTodosOsDias: true,
      ),
      Lembrete(
        id: '${mockPrefix}vitamina_d',
        titulo: 'Vitamina D 2.000 UI (Almoço)',
        horarioHour: 12,
        horarioMinute: 30,
        categoria: LembreteCategoria.medicacao,
        prioridade: LembretePrioridade.normal,
        modoConfirmacao: LembreteModoConfirmacao.simples,
        medicamentoDose: '2 gotas',
        medicamentoEstoque: 50,
        medicamentoEstoqueMinimo: 10,
        idosoId: idosoId,
        repeteTodosOsDias: true,
      ),
      Lembrete(
        id: '${mockPrefix}insulina',
        titulo: 'Insulina / Glicose (Noite - com Foto)',
        horarioHour: 20,
        horarioMinute: 0,
        categoria: LembreteCategoria.medicacao,
        prioridade: LembretePrioridade.critica,
        modoConfirmacao: LembreteModoConfirmacao.foto,
        medicamentoDose: '10 unidades',
        medicamentoEstoque: 15,
        medicamentoEstoqueMinimo: 5,
        idosoId: idosoId,
        repeteTodosOsDias: true,
      ),
      Lembrete(
        id: '${mockPrefix}caminhada',
        titulo: 'Caminhada Leve 20 min',
        horarioHour: 17,
        horarioMinute: 0,
        categoria: LembreteCategoria.exercicio,
        prioridade: LembretePrioridade.normal,
        modoConfirmacao: LembreteModoConfirmacao.simples,
        idosoId: idosoId,
        repeteTodosOsDias: true,
      ),
      Lembrete(
        id: '${mockPrefix}agua',
        titulo: 'Beber Copo de Água',
        horarioHour: 10,
        horarioMinute: 0,
        categoria: LembreteCategoria.hidratacao,
        prioridade: LembretePrioridade.normal,
        modoConfirmacao: LembreteModoConfirmacao.simples,
        idosoId: idosoId,
        repeteTodosOsDias: true,
      ),
    ];

    for (final reminder in mockReminders) {
      await LembreteService.instance.adicionar(reminder);
    }

    int generatedEventsCount = 0;

    // Gerar eventos para os últimos 7 dias
    for (int dayOffset = 6; dayOffset >= 0; dayOffset--) {
      final date = now.subtract(Duration(days: dayOffset));

      for (final reminder in mockReminders) {
        final occurrenceKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}:${reminder.id}';

        // Padrão de simulação realista (90% adesão)
        LembreteStatus status = LembreteStatus.concluido;
        String method = 'botao';
        String? note;

        if (reminder.modoConfirmacao == LembreteModoConfirmacao.foto) {
          status = LembreteStatus.concluidoComFoto;
          method = 'foto';
        }

        // Simula 1 atraso e 1 perda no histórico para dar realismo aos gráficos
        if (dayOffset == 2 && reminder.id.contains('vitamina_d')) {
          status = LembreteStatus.adiado;
          note = 'Adiado por 15 minutos e tomado depois';
        } else if (dayOffset == 4 && reminder.id.contains('caminhada')) {
          status = LembreteStatus.perdido;
          note = 'Não realizado (dia chuvoso)';
        }

        final eventTime = DateTime(
          date.year,
          date.month,
          date.day,
          reminder.horarioHour,
          reminder.horarioMinute + (dayOffset == 1 ? 5 : 0),
        );

        final event = LembreteEvento(
          id: 'mock_event_${reminder.id}_${eventTime.millisecondsSinceEpoch}',
          lembreteId: reminder.id,
          titulo: reminder.titulo,
          categoria: reminder.categoria,
          status: status,
          registradoEm: eventTime,
          idosoId: idosoId,
          observacao: note ?? 'Confirmado com sucesso',
          ocorrenciaChave: occurrenceKey,
          metodoConfirmacao: method,
          atorPapel: 'idoso',
        );

        await LembreteService.instance.registrarEvento(event);
        generatedEventsCount++;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_mock_data_sandbox', true);

    return generatedEventsCount;
  }

  /// Limpa todos os dados simulados gerados pelo Sandbox
  Future<int> clearMockData() async {
    final lembretes = List<Lembrete>.from(LembreteService.instance.lembretes);
    int removedCount = 0;

    for (final reminder in lembretes) {
      if (reminder.id.startsWith(mockPrefix) ||
          reminder.id == testReminderId ||
          reminder.id == testPhotoReminderId ||
          reminder.id == 'test_hub_emergency_reminder') {
        await LembreteService.instance.remover(reminder.id);
        removedCount++;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_mock_data_sandbox');

    return removedCount;
  }

  /// Verifica se há dados de teste/mock ativos no momento
  bool hasMockData() {
    final lembretes = LembreteService.instance.lembretes;
    return lembretes.any(
      (l) =>
          l.id.startsWith(mockPrefix) ||
          l.id == testReminderId ||
          l.id == testPhotoReminderId ||
          l.id == 'test_hub_emergency_reminder',
    );
  }
}
