import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
import 'smart_alert_service.dart';

class LembreteService {
  LembreteService._();
  static final LembreteService _instance = LembreteService._();
  static LembreteService get instance => _instance;

  final List<Lembrete> _lembretes = [];
  final List<LembreteEvento> _eventos = [];
  final ValueNotifier<List<Lembrete>> notifier = ValueNotifier([]);
  final ValueNotifier<List<LembreteEvento>> eventosNotifier = ValueNotifier([]);
  bool _loaded = false;

  List<Lembrete> get lembretes => List.unmodifiable(_lembretes);
  List<LembreteEvento> get eventos => List.unmodifiable(_eventos);

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getActiveIdosoId() async {
    final prefs = await SharedPreferences.getInstance();
    final supervisorActive = prefs.getString('selected_idoso_id');
    final elderlyActive = prefs.getString('paired_idoso_id');
    return supervisorActive ?? elderlyActive ?? 'joao';
  }

  Future<void> carregar() async {
    if (_loaded) return;
    _loaded = true;

    await _carregarCacheLocal();
    await OfflineSyncService.instance.loadQueue();
    await OfflineSyncService.instance.syncPendingWrites();

    if (!_useFirebase) return;

    final idosoId = await _getActiveIdosoId();
    FirebaseFirestore.instance
        .collection('lembretes')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen((snapshot) async {
          _lembretes
            ..clear()
            ..addAll(snapshot.docs.map((doc) => Lembrete.fromJson(doc.data())))
            ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
          await _verificarEFiltrarViradaDoDia();
          await _salvarLembretesLocais();
          await _publicarLembretes();
          await OfflineSyncService.instance.syncPendingWrites();
        });
  }

  Future<void> _carregarCacheLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('lembretes');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _lembretes
        ..clear()
        ..addAll(
          list.map((item) => Lembrete.fromJson(item as Map<String, dynamic>)),
        );
    }

    await _verificarEFiltrarViradaDoDia();

    final eventosData = prefs.getString('lembretes_eventos');
    if (eventosData != null) {
      final list = jsonDecode(eventosData) as List;
      _eventos
        ..clear()
        ..addAll(
          list.map(
            (item) => LembreteEvento.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    eventosNotifier.value = List.from(_eventos);
    await _publicarLembretes();
  }

  Future<void> _verificarEFiltrarViradaDoDia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoje = DateTime.now().toIso8601String().substring(0, 10);
      final ultimoDiaVerificado = prefs.getString('ultimo_dia_verificado');

      if (ultimoDiaVerificado != hoje) {
        bool houveAlteracao = false;
        
        for (int i = 0; i < _lembretes.length; i++) {
          final lembrete = _lembretes[i];
          
          final isRecorrente = lembrete.repeteTodosOsDias || 
                               lembrete.recorrenciaSemanal || 
                               lembrete.recorrenciaMensal || 
                               lembrete.recorrenciaIntervalo ||
                               lembrete.recorrencia == 'diario' ||
                               lembrete.recorrencia == 'semanal' ||
                               lembrete.recorrencia == 'mensal';

          if (isRecorrente && (lembrete.concluido || lembrete.concluidoComFoto)) {
            _lembretes[i] = lembrete.copyWith(
              concluido: false,
              concluidoComFoto: false,
              status: LembreteStatus.pendente,
            );
            houveAlteracao = true;

            if (_useFirebase) {
              await OfflineSyncService.instance.updateOrQueue(
                'lembretes',
                lembrete.id,
                {
                  'concluido': false,
                  'concluidoComFoto': false,
                  'status': 'pendente',
                },
              );
            }
          }
        }

        if (houveAlteracao) {
          await _salvarLembretesLocais();
          await _publicarLembretes();
        }

        await prefs.setString('ultimo_dia_verificado', hoje);
      }
    } catch (e) {
      debugPrint('Erro ao verificar virada do dia: $e');
    }
  }

  Future<void> _salvar() async {
    await _salvarLembretesLocais();
    await _publicarLembretes();
  }

  Future<void> _salvarLembretesLocais() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_lembretes.map((l) => l.toJson()).toList());
    await prefs.setString('lembretes', data);
  }

  Future<void> _salvarEventosLocais() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_eventos.map((e) => e.toJson()).toList());
    await prefs.setString('lembretes_eventos', data);
    eventosNotifier.value = List.from(_eventos);
  }

  Future<void> _publicarLembretes() async {
    notifier.value = List.from(_lembretes);
    NotificationService.instance.agendarTodos(_lembretes);
    await SmartAlertService.instance.atualizar(_lembretes);
  }

  void _upsertLocal(Lembrete lembrete) {
    final idx = _lembretes.indexWhere((item) => item.id == lembrete.id);
    if (idx == -1) {
      _lembretes.add(lembrete);
    } else {
      _lembretes[idx] = lembrete;
    }
  }

  Lembrete? _findLocal(String id) {
    try {
      return _lembretes.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Lembrete?> _findLocalOrRemote(String id) async {
    final local = _findLocal(id);
    if (local != null) return local;
    if (!_useFirebase) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists || doc.data() == null) return null;
      return Lembrete.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Nao foi possivel buscar lembrete remoto $id: $e');
      return null;
    }
  }

  Future<void> _registrarEvento(
    Lembrete lembrete,
    LembreteStatus status, {
    String? observacao,
  }) async {
    final evento = LembreteEvento.fromLembrete(
      lembrete,
      status: status,
      observacao: observacao,
    );

    _eventos.insert(0, evento);
    await _salvarEventosLocais();

    if (_useFirebase) {
      await OfflineSyncService.instance.setOrQueue(
        'lembrete_eventos',
        evento.id,
        evento.toJson(),
      );
    }
  }

  bool _bloqueiaConclusaoSemFoto(Lembrete lembrete, LembreteStatus status) {
    return lembrete.categoria == 'medicacao' &&
        status.isConcluido &&
        status != LembreteStatus.concluidoComFoto;
  }

  Future<void> _atualizarStatus(
    String id,
    LembreteStatus status, {
    String? observacao,
  }) async {
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return;
    if (_bloqueiaConclusaoSemFoto(lembrete, status)) return;

    final atualizado = lembrete.copyWith(status: status);
    _upsertLocal(atualizado);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue('lembretes', id, {
        'status': status.storageValue,
        'concluido': status.isConcluido,
        'concluidoComFoto': status == LembreteStatus.concluidoComFoto,
      });
    }

    await _registrarEvento(atualizado, status, observacao: observacao);
  }

  Future<void> _atualizarLocalERemoto(
    String id,
    Lembrete Function(Lembrete lembrete) updateLocal,
    Map<String, dynamic> remotePatch,
  ) async {
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return;

    final atualizado = updateLocal(lembrete);
    _upsertLocal(atualizado);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue(
        'lembretes',
        id,
        remotePatch,
      );
    }
  }

  Future<void> adicionar(Lembrete lembrete) async {
    final idosoId = await _getActiveIdosoId();
    final titulo = lembrete.titulo.isEmpty
        ? lembrete.titulo
        : lembrete.titulo[0].toUpperCase() + lembrete.titulo.substring(1);
    final novo = lembrete.copyWith(titulo: titulo, idosoId: idosoId);

    _upsertLocal(novo);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.setOrQueue(
        'lembretes',
        novo.id,
        novo.toJson(),
      );
    }
  }

  Future<void> concluir(String id) async {
    await _atualizarStatus(id, LembreteStatus.concluido);
  }

  Future<void> concluirComFoto(String id) async {
    await _atualizarStatus(id, LembreteStatus.concluidoComFoto);
  }

  Future<void> alternarConclusao(String id) async {
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return;

    final novoStatus = lembrete.concluido
        ? LembreteStatus.pendente
        : LembreteStatus.concluido;
    if (_bloqueiaConclusaoSemFoto(lembrete, novoStatus)) return;

    final atualizado = lembrete.copyWith(status: novoStatus);
    _upsertLocal(atualizado);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue('lembretes', id, {
        'status': novoStatus.storageValue,
        'concluido': novoStatus.isConcluido,
        'concluidoComFoto': false,
      });
    }
    await _registrarEvento(atualizado, novoStatus);
  }

  Future<void> remover(String id) async {
    _lembretes.removeWhere((item) => item.id == id);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.deleteOrQueue('lembretes', id);
    }
  }

  Future<void> atualizarHorario(String id, int hour, int minute) async {
    await _atualizarLocalERemoto(
      id,
      (lembrete) => lembrete.copyWith(horarioHour: hour, horarioMinute: minute),
      {'horarioHour': hour, 'horarioMinute': minute},
    );
  }

  Future<void> atualizarTitulo(String id, String novoTitulo) async {
    final tituloCapitalizado = novoTitulo.isEmpty
        ? novoTitulo
        : novoTitulo[0].toUpperCase() + novoTitulo.substring(1);
    await _atualizarLocalERemoto(
      id,
      (lembrete) => lembrete.copyWith(titulo: tituloCapitalizado),
      {'titulo': tituloCapitalizado},
    );
  }

  Future<void> adiar(String id, int minutos) async {
    final now = DateTime.now().add(Duration(minutes: minutos));
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return;

    final atualizado = lembrete.copyWith(
      horarioHour: now.hour,
      horarioMinute: now.minute,
      status: LembreteStatus.adiado,
    );
    _upsertLocal(atualizado);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue('lembretes', id, {
        'horarioHour': now.hour,
        'horarioMinute': now.minute,
        'status': LembreteStatus.adiado.storageValue,
        'concluido': false,
        'concluidoComFoto': false,
      });
    }
    await _registrarEvento(
      atualizado,
      LembreteStatus.adiado,
      observacao: 'Adiado por $minutos minutos',
    );
  }

  Future<void> registrarDificuldade(String id, String motivo) async {
    await _atualizarStatus(id, LembreteStatus.perdido, observacao: motivo);
  }

  Future<void> registrarWelfareCheckin(String emotion) async {
    final mockLembrete = Lembrete(
      id: 'welfare_${DateTime.now().millisecondsSinceEpoch}',
      titulo: 'Check-in de Bem-estar',
      horarioHour: DateTime.now().hour,
      horarioMinute: DateTime.now().minute,
      categoria: 'bem_estar',
      idosoId: await _getActiveIdosoId(),
    );
    await _registrarEvento(
      mockLembrete,
      LembreteStatus.concluido,
      observacao: emotion,
    );
  }
}
