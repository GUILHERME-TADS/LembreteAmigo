import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/offline_write.dart';
import '../utils/audio_path_helper.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';
import 'smart_alert_service.dart';
import 'widget_service.dart';

class LembreteService {
  LembreteService._();
  static final LembreteService _instance = LembreteService._();
  static LembreteService get instance => _instance;

  final List<Lembrete> _lembretes = [];
  final List<LembreteEvento> _eventos = [];
  final ValueNotifier<List<Lembrete>> notifier = ValueNotifier([]);
  final ValueNotifier<List<LembreteEvento>> eventosNotifier = ValueNotifier([]);
  bool _loaded = false;
  String? _loadedIdosoId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _lembretesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventosSubscription;
  Future<void>? _carregarFuture;

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
    return SessionRoleService.getActiveIdosoId();
  }

  Future<void> carregar() async {
    if (SessionRoleService.isSupervisor) {
      final idosoId = await _getActiveIdosoId();
      if (idosoId == SessionRoleService.unpairedIdosoId) {
        await _lembretesSubscription?.cancel();
        _lembretesSubscription = null;
        await _eventosSubscription?.cancel();
        _eventosSubscription = null;
        await _cancelarNotificacoesLocais();
        _lembretes.clear();
        _eventos.clear();
        notifier.value = const [];
        eventosNotifier.value = const [];
        _carregarFuture = null;
        _loaded = false;
        _loadedIdosoId = null;
        return;
      }
    }

    final idosoId = await _getActiveIdosoId();
    if (_loaded && _loadedIdosoId == idosoId) {
      if (_carregarFuture != null) {
        await _carregarFuture;
      }
      return;
    }

    if (_loadedIdosoId != null && _loadedIdosoId != idosoId) {
      await _lembretesSubscription?.cancel();
      _lembretesSubscription = null;
      await _eventosSubscription?.cancel();
      _eventosSubscription = null;
      await _cancelarNotificacoesLocais();
      _lembretes.clear();
      _eventos.clear();
      notifier.value = const [];
      eventosNotifier.value = const [];
      _carregarFuture = null;
      _loaded = false;
    }

    _loadedIdosoId = idosoId;
    _loaded = true;

    _carregarFuture = _executarCarregar(idosoId);
    await _carregarFuture;
  }

  Future<void> reset() async {
    await _lembretesSubscription?.cancel();
    _lembretesSubscription = null;
    await _eventosSubscription?.cancel();
    _eventosSubscription = null;
    _lembretes.clear();
    _eventos.clear();
    notifier.value = const [];
    eventosNotifier.value = const [];
    _loaded = false;
    _loadedIdosoId = null;
    _carregarFuture = null;
  }


  Future<void> _executarCarregar(String idosoId) async {
    await _carregarCacheLocal(activeIdosoId: idosoId);
    await OfflineSyncService.instance.loadQueue();
    await OfflineSyncService.instance.syncPendingWrites();

    if (!_useFirebase) return;

    await _lembretesSubscription?.cancel();
    _lembretesSubscription = FirebaseFirestore.instance
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
        }, onError: (Object error, StackTrace stackTrace) {
          debugPrint('Erro ao escutar lembretes no Firestore: $error');
        });

    await _eventosSubscription?.cancel();
    _eventosSubscription = FirebaseFirestore.instance
        .collection('lembrete_eventos')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen((snapshot) async {
          _eventos
            ..clear()
            ..addAll(
              snapshot.docs.map((doc) => LembreteEvento.fromJson(doc.data())),
            )
            ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
          await _salvarEventosLocais();
        }, onError: (Object error, StackTrace stackTrace) {
          debugPrint('Erro ao escutar eventos no Firestore: $error');
        });
  }

  String _lembretesCacheKey(String? idosoId) =>
      idosoId == null ? 'lembretes' : 'lembretes_$idosoId';

  String _eventosCacheKey(String? idosoId) =>
      idosoId == null ? 'lembretes_eventos' : 'lembretes_eventos_$idosoId';

  String _dayCheckKey(String? idosoId) => idosoId == null
      ? 'ultimo_dia_verificado'
      : 'ultimo_dia_verificado_$idosoId';

  Future<List<dynamic>?> _readListCache(
    List<String> keys,
    String label,
  ) async {
    for (final key in keys) {
      final raw = await SecureCacheService.instance.read(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
        debugPrint('Cache $label em $key nao contem uma lista.');
      } catch (e) {
        debugPrint('Cache $label corrompido em $key. Removendo: $e');
      }
      await SecureCacheService.instance.delete(key);
    }
    return null;
  }

  Future<void> _carregarCacheLocal({String? activeIdosoId}) async {
    if (SessionRoleService.isSupervisor) return;
    final lembretesCache = await _readListCache([
      _lembretesCacheKey(activeIdosoId),
      'lembretes',
    ], 'lembretes');
    if (lembretesCache != null) {
      final lembretes = <Lembrete>[];
      for (final item in lembretesCache) {
        try {
          final lembrete = Lembrete.fromJson(item as Map<String, dynamic>);
          if (activeIdosoId == null ||
              lembrete.idosoId == null ||
              lembrete.idosoId == activeIdosoId) {
            lembretes.add(lembrete);
          }
        } catch (e) {
          debugPrint('Lembrete local invalido ignorado: $e');
        }
      }
      _lembretes
        ..clear()
        ..addAll(lembretes);
    }

    await _verificarEFiltrarViradaDoDia();

    final eventosCache = await _readListCache([
      _eventosCacheKey(activeIdosoId),
      'lembretes_eventos',
    ], 'eventos');
    if (eventosCache != null) {
      final eventos = <LembreteEvento>[];
      for (final item in eventosCache) {
        try {
          final evento = LembreteEvento.fromJson(
            item as Map<String, dynamic>,
          );
          if (activeIdosoId == null ||
              evento.idosoId == null ||
              evento.idosoId == activeIdosoId) {
            eventos.add(evento);
          }
        } catch (e) {
          debugPrint('Evento local invalido ignorado: $e');
        }
      }
      _eventos
        ..clear()
        ..addAll(eventos);
    }

    eventosNotifier.value = List.from(_eventos);
    await _publicarLembretes();
  }

  Future<void> _verificarEFiltrarViradaDoDia() async {
    if (SessionRoleService.isSupervisor) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoje = DateTime.now().toIso8601String().substring(0, 10);
      final dayCheckKey = _dayCheckKey(_loadedIdosoId);
      final ultimoDiaVerificado = prefs.getString(dayCheckKey);

      if (ultimoDiaVerificado != hoje) {
        bool houveAlteracao = false;
        final List<OfflineWrite> pendingSyncWrites = [];

        for (int i = 0; i < _lembretes.length; i++) {
          final lembrete = _lembretes[i];

          final isRecorrente =
              lembrete.repeteTodosOsDias ||
              lembrete.recorrenciaSemanal ||
              lembrete.recorrenciaMensal ||
              lembrete.recorrenciaIntervalo ||
              lembrete.recorrencia == 'diario' ||
              lembrete.recorrencia == 'semanal' ||
              lembrete.recorrencia == 'mensal' ||
              lembrete.recorrencia == 'quinzenal';

          final originalHour = lembrete.originalHorarioHour ?? lembrete.horarioHour;
          final originalMinute = lembrete.originalHorarioMinute ?? lembrete.horarioMinute;
          final horarioMudou = lembrete.horarioHour != originalHour || lembrete.horarioMinute != originalMinute;

          if (isRecorrente &&
              (lembrete.concluido || lembrete.concluidoComFoto || lembrete.status == LembreteStatus.adiado || horarioMudou)) {
            _lembretes[i] = lembrete.copyWith(
              horarioHour: originalHour,
              horarioMinute: originalMinute,
              concluido: false,
              concluidoComFoto: false,
              status: LembreteStatus.pendente,
            );
            houveAlteracao = true;

            if (_useFirebase) {
              pendingSyncWrites.add(OfflineWrite(
                id: '${DateTime.now().microsecondsSinceEpoch}_${pendingSyncWrites.length}',
                collection: 'lembretes',
                docId: lembrete.id,
                action: OfflineWriteAction.update,
                data: {
                  'horarioHour': originalHour,
                  'horarioMinute': originalMinute,
                  'concluido': false,
                  'concluidoComFoto': false,
                  'status': 'pendente',
                },
              ));
            }
          }
        }

        if (pendingSyncWrites.isNotEmpty) {
          await OfflineSyncService.instance.enqueueMultiple(pendingSyncWrites);
        }

        if (houveAlteracao) {
          await _salvarLembretesLocais();
          await _publicarLembretes();
        }

        await prefs.setString(dayCheckKey, hoje);
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
    if (SessionRoleService.isSupervisor) return;
    final data = jsonEncode(_lembretes.map((l) => l.toJson()).toList());
    await SecureCacheService.instance.write(
      _lembretesCacheKey(_loadedIdosoId),
      data,
    );
  }

  Future<void> _salvarEventosLocais() async {
    if (SessionRoleService.isSupervisor) return;
    final data = jsonEncode(_eventos.map((e) => e.toJson()).toList());
    await SecureCacheService.instance.write(
      _eventosCacheKey(_loadedIdosoId),
      data,
    );
    eventosNotifier.value = List.from(_eventos);
  }

  Future<void> _publicarLembretes() async {
    notifier.value = List.from(_lembretes);
    if (!SessionRoleService.isSupervisor) {
      try {
        await NotificationService.instance.agendarTodos(_lembretes);
      } catch (e) {
        debugPrint('Erro ao reagendar notificacoes: $e');
      }
    } else {
      try {
        await NotificationService.instance.cancelarTodas();
      } catch (e) {
        debugPrint('Erro ao cancelar todas notificacoes: $e');
      }
    }
    await SmartAlertService.instance.atualizar(_lembretes, eventos: _eventos);
    await WidgetService.instance.atualizar();
  }

  Future<void> _cancelarNotificacoesLocais() async {
    for (final lembrete in _lembretes) {
      await NotificationService.instance.cancelar(lembrete.id);
    }
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
    final source = lembrete.idosoId == null
        ? lembrete.copyWith(idosoId: await _getActiveIdosoId())
        : lembrete;
    final evento = LembreteEvento.fromLembrete(
      source,
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

  Future<bool> _checkConnection() async {
    final idosoId = await _getActiveIdosoId();
    return idosoId != SessionRoleService.unpairedIdosoId;
  }

  Future<void> adicionar(Lembrete lembrete) async {
    if (!await _checkConnection()) return;
    final idosoId = await _getActiveIdosoId();
    final titulo = lembrete.titulo.isEmpty
        ? lembrete.titulo
        : lembrete.titulo[0].toUpperCase() + lembrete.titulo.substring(1);

    String? audioPath = lembrete.audioPath;
    try {
      audioPath = await _uploadAudioIfNeeded(
        audioPath: lembrete.audioPath,
        idosoId: idosoId,
        lembreteId: lembrete.id,
      );
    } catch (e) {
      debugPrint('Erro ao subir audio no cadastro de lembrete (salvando local): $e');
    }

    String? medicamentoFotoPath = lembrete.medicamentoFotoPath;
    try {
      medicamentoFotoPath = await _uploadMedicationPhotoIfNeeded(
        photoPath: lembrete.medicamentoFotoPath,
        idosoId: idosoId,
        lembreteId: lembrete.id,
      );
    } catch (e) {
      debugPrint('Erro ao subir foto no cadastro de lembrete (salvando local): $e');
    }

    final novo = lembrete.copyWith(
      titulo: titulo,
      idosoId: idosoId,
      audioPath: audioPath,
      medicamentoFotoPath: medicamentoFotoPath,
    );

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

  Future<String?> _uploadAudioIfNeeded({
    required String? audioPath,
    required String idosoId,
    required String lembreteId,
  }) async {
    if (audioPath == null || audioPath.isEmpty) return audioPath;
    if (!_useFirebase || isRemoteAudioPath(audioPath)) return audioPath;

    final file = File(audioPath);
    if (!await file.exists()) {
      throw StateError('Arquivo de audio nao encontrado.');
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('reminder_audio')
        .child(idosoId)
        .child('$lembreteId.m4a');
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/mp4'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<String?> _uploadMedicationPhotoIfNeeded({
    required String? photoPath,
    required String idosoId,
    required String lembreteId,
  }) async {
    if (photoPath == null || photoPath.isEmpty) return photoPath;
    if (!_useFirebase ||
        isRemotePath(photoPath) ||
        photoPath.startsWith('assets/')) {
      return photoPath;
    }

    final file = File(photoPath);
    if (!await file.exists()) {
      throw StateError('Foto do medicamento nao encontrada.');
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('reminder_photos')
        .child(idosoId)
        .child('$lembreteId.jpg');
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> concluir(String id) async {
    if (!await _checkConnection()) return;
    await _atualizarStatus(id, LembreteStatus.concluido);
  }

  Future<void> concluirComFoto(String id, String localPhotoPath) async {
    if (!await _checkConnection()) return;

    final idosoId = await _getActiveIdosoId();
    String finalPath = localPhotoPath;

    if (_useFirebase) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('confirmation_photos')
            .child(idosoId)
            .child('$id.jpg');
        final uploadTask = await ref.putFile(File(localPhotoPath));
        finalPath = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint('Erro ao fazer upload da foto de confirmacao: $e');
      }
    }

    await _atualizarLocalERemoto(
      id,
      (lembrete) => lembrete.copyWith(
        status: LembreteStatus.concluidoComFoto,
        medicamentoFotoPath: finalPath,
      ),
      {
        'status': LembreteStatus.concluidoComFoto.storageValue,
        'concluido': true,
        'concluidoComFoto': true,
        'medicamentoFotoPath': finalPath,
      },
    );

    final updated = _findLocal(id);
    if (updated != null) {
      await _registrarEvento(updated, LembreteStatus.concluidoComFoto,
          observacao: 'Medicação confirmada com foto.');
    }
  }

  Future<void> alternarConclusao(String id) async {
    if (!await _checkConnection()) return;
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
    if (!await _checkConnection()) return;
    await NotificationService.instance.cancelar(id);
    _lembretes.removeWhere((item) => item.id == id);
    await _salvar();

    if (_useFirebase) {
      await OfflineSyncService.instance.deleteOrQueue('lembretes', id);
    }
  }


  Future<void> atualizarHorario(String id, int hour, int minute) async {
    if (!await _checkConnection()) return;
    await _atualizarLocalERemoto(
      id,
      (lembrete) => lembrete.copyWith(
        horarioHour: hour,
        horarioMinute: minute,
        originalHorarioHour: hour,
        originalHorarioMinute: minute,
      ),
      {
        'horarioHour': hour,
        'horarioMinute': minute,
        'originalHorarioHour': hour,
        'originalHorarioMinute': minute,
      },
    );
  }

  Future<void> atualizarTitulo(String id, String novoTitulo) async {
    if (!await _checkConnection()) return;
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
    if (!await _checkConnection()) return;
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
    if (!await _checkConnection()) return;
    await _atualizarStatus(id, LembreteStatus.perdido, observacao: motivo);
  }

  Future<void> registrarWelfareCheckin(String emotion) async {
    if (!await _checkConnection()) return;
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
