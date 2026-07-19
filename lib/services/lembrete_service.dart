import 'dart:async';
import 'dart:convert';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/offline_write.dart';
import '../utils/audio_path_helper.dart';
import '../utils/firebase_helper.dart';
import 'media_upload_service.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
import 'remote_media_cache_service.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';
import 'smart_alert_service.dart';
import 'widget_service.dart';
import 'app_status_service.dart';
import 'durable_media_service.dart';

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
  bool _hasRemoteReminderSnapshot = false;

  List<Lembrete> get lembretes => List.unmodifiable(_lembretes);
  List<LembreteEvento> get eventos => List.unmodifiable(_eventos);

  bool get _useFirebase => FirebaseHelper.isInitialized;

  bool _canSyncIdosoId(String? idosoId) {
    return _useFirebase && !SessionRoleService.isLocalOnlyIdosoId(idosoId);
  }

  Future<String> _getActiveIdosoId() async {
    return SessionRoleService.getActiveIdosoId();
  }

  String? _cacheIdosoId(String? idosoId) {
    if (idosoId == null || idosoId.isEmpty) return null;
    if (SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
      return SessionRoleService.autonomousIdosoId;
    }
    return idosoId;
  }

  bool _matchesActiveIdosoId(String? itemIdosoId, String? activeIdosoId) {
    final activeCacheId = _cacheIdosoId(activeIdosoId);
    if (activeCacheId == null) return true;
    if (itemIdosoId == null || itemIdosoId.isEmpty) return true;
    if (SessionRoleService.isElderly &&
        SessionRoleService.isLocalOnlyIdosoId(itemIdosoId)) {
      return true;
    }
    return _cacheIdosoId(itemIdosoId) == activeCacheId;
  }

  Future<void> carregar() async {
    if (SessionRoleService.isSupervisor) {
      final idosoId = await _getActiveIdosoId();
      if (SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
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
        _hasRemoteReminderSnapshot = false;
        return;
      }
    }

    final idosoId = await _getActiveIdosoId();
    if (_loaded && _loadedIdosoId == idosoId) {
      if (_carregarFuture != null) {
        await _carregarFuture;
      }
      await _verificarEFiltrarViradaDoDia();
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
      _hasRemoteReminderSnapshot = false;
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
    _hasRemoteReminderSnapshot = false;
  }

  void pauseSubscriptions() {
    _lembretesSubscription?.pause();
    _eventosSubscription?.pause();
  }

  void resumeSubscriptions() {
    _lembretesSubscription?.resume();
    _eventosSubscription?.resume();
  }

  Future<void> _executarCarregar(String idosoId) async {
    await _carregarCacheLocal(activeIdosoId: idosoId);
    await OfflineSyncService.instance.loadQueue();

    if (!_canSyncIdosoId(idosoId)) return;
    await OfflineSyncService.instance.syncPendingWrites();

    await _lembretesSubscription?.cancel();
    _lembretesSubscription = FirebaseFirestore.instance
        .collection('lembretes')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen(
          (snapshot) async {
            final previousStatuses = <String, LembreteStatus>{
              for (final item in _lembretes) item.id: item.status,
            };
            final shouldNotifyStatusChanges =
                SessionRoleService.isSupervisor && _hasRemoteReminderSnapshot;
            final localItemsById = <String, Lembrete>{
              for (final item in _lembretes) item.id: item,
            };
            final pendingWrites =
                (await OfflineSyncService.instance.loadQueue())
                    .where((write) => write.collection == 'lembretes')
                    .toList();
            final itemsById = <String, Lembrete>{};
            await Future.wait(
              snapshot.docs.map((doc) async {
                final data = Map<String, dynamic>.from(doc.data());
                if (data['audioPath'] is String &&
                    data['audioPath'] != 'ia_generated') {
                  data['audioPath'] = await RemoteMediaCacheService.instance
                      .resolve(data['audioPath'] as String?);
                }
                if (data['medicamentoFotoPath'] is String) {
                  data['medicamentoFotoPath'] = await RemoteMediaCacheService
                      .instance
                      .resolve(data['medicamentoFotoPath'] as String?);
                }
                itemsById[doc.id] = Lembrete.fromJson(data);
              }),
            );

            for (final entry in localItemsById.entries) {
              final remote = itemsById[entry.key];
              final local = entry.value;
              if (remote == null) continue;
              if (remote.status == LembreteStatus.pendente &&
                  local.status != LembreteStatus.pendente) {
                itemsById[entry.key] = local;
              }
            }

            for (final write in pendingWrites) {
              if (write.action == OfflineWriteAction.delete) {
                itemsById.remove(write.docId);
                continue;
              }

              final data = Map<String, dynamic>.from(write.data);
              final pendingIdosoId =
                  data['idosoId'] as String? ??
                  itemsById[write.docId]?.idosoId ??
                  idosoId;
              if (pendingIdosoId != idosoId) continue;

              if (write.action == OfflineWriteAction.set) {
                itemsById[write.docId] = Lembrete.fromJson(data);
                continue;
              }

              final current = itemsById[write.docId];
              if (current != null) {
                itemsById[write.docId] = Lembrete.fromJson(
                  Map<String, dynamic>.from(current.toJson())..addAll(data),
                );
              }
            }

            final items = itemsById.values.toList();

            _lembretes
              ..clear()
              ..addAll(items)
              ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
            await _verificarEFiltrarViradaDoDia();
            await _salvarLembretesLocais();
            await _publicarLembretes();
            if (shouldNotifyStatusChanges) {
              for (final item in items) {
                final previous = previousStatuses[item.id];
                if (previous == null || previous == item.status) continue;
                if (item.status == LembreteStatus.pendente) continue;
                await NotificationService.instance.mostrarConfirmacaoCuidador(
                  lembrete: item,
                  status: item.status,
                );
              }
            }
            _hasRemoteReminderSnapshot = true;
            await OfflineSyncService.instance.syncPendingWrites();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Erro ao escutar lembretes no Firestore: $error');
          },
        );

    await _eventosSubscription?.cancel();
    _eventosSubscription = FirebaseFirestore.instance
        .collection('lembrete_eventos')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen(
          (snapshot) async {
            _eventos
              ..clear()
              ..addAll(
                snapshot.docs.map((doc) => LembreteEvento.fromJson(doc.data())),
              )
              ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
            await _salvarEventosLocais();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Erro ao escutar eventos no Firestore: $error');
          },
        );
  }

  String _lembretesCacheKey(String? idosoId) {
    final cacheIdosoId = _cacheIdosoId(idosoId);
    return cacheIdosoId == null ? 'lembretes' : 'lembretes_$cacheIdosoId';
  }

  String _elderlyBackupCacheKey(String? idosoId) {
    return 'elderly_backup_${_lembretesCacheKey(idosoId)}';
  }

  String _eventosCacheKey(String? idosoId) {
    final cacheIdosoId = _cacheIdosoId(idosoId);
    return cacheIdosoId == null
        ? 'lembretes_eventos'
        : 'lembretes_eventos_$cacheIdosoId';
  }

  String _dayCheckKey(String? idosoId) {
    final cacheIdosoId = _cacheIdosoId(idosoId);
    return cacheIdosoId == null
        ? 'ultimo_dia_verificado'
        : 'ultimo_dia_verificado_$cacheIdosoId';
  }

  List<String> _lembretesCacheKeysForRead(String? activeIdosoId) {
    if (SessionRoleService.isLocalOnlyIdosoId(activeIdosoId)) {
      return [
        _elderlyBackupCacheKey(SessionRoleService.autonomousIdosoId),
        _lembretesCacheKey(SessionRoleService.autonomousIdosoId),
      ];
    }
    return [
      if (SessionRoleService.isElderly) _elderlyBackupCacheKey(activeIdosoId),
      _lembretesCacheKey(activeIdosoId),
    ];
  }

  List<String> _eventosCacheKeysForRead(String? activeIdosoId) {
    if (SessionRoleService.isLocalOnlyIdosoId(activeIdosoId)) {
      return [
        _eventosCacheKey(SessionRoleService.autonomousIdosoId),
      ];
    }
    return [_eventosCacheKey(activeIdosoId)];
  }

  Future<List<dynamic>?> _readListCache(List<String> keys, String label) async {
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

  Future<void> _runOneTimeCacheMigration() async {
    final secureCache = SecureCacheService.instance;
    final targetRemindersKey = 'lembretes_idoso_local';
    final targetBackupRemindersKey = 'elderly_backup_lembretes_idoso_local';

    // Check if new unified local key has data
    final existingLocal = await secureCache.read(targetRemindersKey);
    final existingBackup = await secureCache.read(targetBackupRemindersKey);

    final bool hasExistingLocalData = (existingLocal != null && existingLocal.isNotEmpty) ||
                                       (existingBackup != null && existingBackup.isNotEmpty);

    // If it doesn't have data, attempt to find data in the old keys
    if (!hasExistingLocalData) {
      final oldRemindersKeys = [
        'lembretes_idoso_autonomo',
        'elderly_backup_lembretes_idoso_autonomo',
        'lembretes_idoso_sem_vinculo',
        'lembretes_idoso_simulado',
        'lembretes',
      ];

      String? foundData;
      for (final key in oldRemindersKeys) {
        final data = await secureCache.read(key);
        if (data != null && data.isNotEmpty) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is List && decoded.isNotEmpty) {
              foundData = data;
              break;
            }
          } catch (_) {}
        }
      }

      if (foundData != null) {
        await secureCache.write(targetRemindersKey, foundData);
        await secureCache.write(targetBackupRemindersKey, foundData);
        debugPrint('Cache de lembretes locais antigos migrado com sucesso para idoso_local.');
      }
    }

    // Repeat the check for events
    final targetEventsKey = 'lembretes_eventos_idoso_local';
    final existingEvents = await secureCache.read(targetEventsKey);
    final bool hasExistingEventsData = existingEvents != null && existingEvents.isNotEmpty;

    if (!hasExistingEventsData) {
      final oldEventsKeys = [
        'lembretes_eventos_idoso_autonomo',
        'lembretes_eventos_idoso_sem_vinculo',
        'lembretes_eventos_idoso_simulado',
        'lembretes_eventos',
      ];

      String? foundData;
      for (final key in oldEventsKeys) {
        final data = await secureCache.read(key);
        if (data != null && data.isNotEmpty) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is List && decoded.isNotEmpty) {
              foundData = data;
              break;
            }
          } catch (_) {}
        }
      }

      if (foundData != null) {
        await secureCache.write(targetEventsKey, foundData);
        debugPrint('Cache de eventos de lembretes antigos migrado com sucesso para idoso_local.');
      }
    }

    // Clean up all old cache keys so they don't linger on the device
    final keysToDelete = [
      'lembretes_idoso_autonomo',
      'elderly_backup_lembretes_idoso_autonomo',
      'lembretes_idoso_sem_vinculo',
      'lembretes_idoso_simulado',
      'lembretes',
      'lembretes_eventos_idoso_autonomo',
      'lembretes_eventos_idoso_sem_vinculo',
      'lembretes_eventos_idoso_simulado',
      'lembretes_eventos',
    ];
    for (final key in keysToDelete) {
      await secureCache.delete(key);
    }
  }

  Future<void> _carregarCacheLocal({String? activeIdosoId}) async {
    await _runOneTimeCacheMigration();
    final activeCacheId = _cacheIdosoId(activeIdosoId);
    final migratedReminders = <Lembrete>[];
    final lembretesCache = await _readListCache(
      _lembretesCacheKeysForRead(activeIdosoId),
      'lembretes',
    );
    if (lembretesCache != null) {
      final lembretes = <Lembrete>[];
      for (final item in lembretesCache) {
        try {
          final lembrete = Lembrete.fromJson(item as Map<String, dynamic>);
          if (_matchesActiveIdosoId(lembrete.idosoId, activeIdosoId)) {
            final shouldMigrate =
                SessionRoleService.isElderly &&
                activeCacheId != null &&
                !SessionRoleService.isLocalOnlyIdosoId(activeIdosoId) &&
                (lembrete.idosoId == null ||
                    SessionRoleService.isLocalOnlyIdosoId(lembrete.idosoId));
            final normalizedIdosoId = shouldMigrate
                ? activeCacheId
                : _cacheIdosoId(lembrete.idosoId);
            final normalized = normalizedIdosoId != lembrete.idosoId
                ? lembrete.copyWith(idosoId: normalizedIdosoId)
                : lembrete;
            lembretes.add(normalized);
            if (shouldMigrate) migratedReminders.add(normalized);
          }
        } catch (e) {
          debugPrint('Lembrete local invalido ignorado: $e');
        }
      }
      _lembretes
        ..clear()
        ..addAll(lembretes);
      if (SessionRoleService.isElderly) {
        await SecureCacheService.instance.write(
          _elderlyBackupCacheKey(activeIdosoId),
          jsonEncode(_lembretes.map((item) => item.toJson()).toList()),
        );
      }
      if (migratedReminders.isNotEmpty) {
        for (final lembrete in migratedReminders) {
          await OfflineSyncService.instance.setOrQueue(
            'lembretes',
            lembrete.id,
            lembrete.toJson(),
          );
        }
      }
    }

    final eventosCache = await _readListCache(
      _eventosCacheKeysForRead(activeIdosoId),
      'eventos',
    );
    if (eventosCache != null) {
      final eventos = <LembreteEvento>[];
      final migratedEvents = <LembreteEvento>[];
      for (final item in eventosCache) {
        try {
          final evento = LembreteEvento.fromJson(item as Map<String, dynamic>);
          if (_matchesActiveIdosoId(evento.idosoId, activeIdosoId)) {
            final shouldMigrate =
                SessionRoleService.isElderly &&
                activeCacheId != null &&
                !SessionRoleService.isLocalOnlyIdosoId(activeIdosoId) &&
                (evento.idosoId == null ||
                    SessionRoleService.isLocalOnlyIdosoId(evento.idosoId));
            final normalized = shouldMigrate
                ? LembreteEvento(
                    id: evento.id,
                    lembreteId: evento.lembreteId,
                    titulo: evento.titulo,
                    categoria: evento.categoria,
                    status: evento.status,
                    registradoEm: evento.registradoEm,
                    idosoId: activeCacheId,
                    observacao: evento.observacao,
                  )
                : evento;
            eventos.add(normalized);
            if (shouldMigrate) migratedEvents.add(normalized);
          }
        } catch (e) {
          debugPrint('Evento local invalido ignorado: $e');
        }
      }
      _eventos
        ..clear()
        ..addAll(eventos);
      await _salvarEventosLocais();
      for (final evento in migratedEvents) {
        await OfflineSyncService.instance.setOrQueue(
          'lembrete_eventos',
          evento.id,
          evento.toJson(),
        );
      }
    }

    await _verificarEFiltrarViradaDoDia();
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
        bool houveNovoEvento = false;
        final List<OfflineWrite> pendingSyncWrites = [];

        final lastChecked = DateTime.tryParse(ultimoDiaVerificado ?? '');
        if (lastChecked != null) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          var missedDate = DateTime(
            lastChecked.year,
            lastChecked.month,
            lastChecked.day,
          );
          while (missedDate.isBefore(todayDate)) {
            for (final lembrete in _lembretes) {
              final createdDate = DateTime(
                lembrete.criadoEm.year,
                lembrete.criadoEm.month,
                lembrete.criadoEm.day,
              );
              if (missedDate.isBefore(createdDate)) continue;
              if (!Lembrete.isReminderActiveOn(lembrete, missedDate)) continue;
              final alreadyRegistered = _eventos.any(
                (evento) =>
                    evento.lembreteId == lembrete.id &&
                    evento.registradoEm.year == missedDate.year &&
                    evento.registradoEm.month == missedDate.month &&
                    evento.registradoEm.day == missedDate.day,
              );
              if (alreadyRegistered) continue;

              final registeredAt = DateTime(
                missedDate.year,
                missedDate.month,
                missedDate.day,
                lembrete.originalHorarioHour ?? lembrete.horarioHour,
                lembrete.originalHorarioMinute ?? lembrete.horarioMinute,
              );
              final eventId =
                  '${lembrete.id}_missed_${missedDate.toIso8601String().substring(0, 10)}';
              final evento = LembreteEvento(
                id: eventId,
                lembreteId: lembrete.id,
                titulo: lembrete.titulo,
                categoria: lembrete.categoria,
                status: LembreteStatus.perdido,
                registradoEm: registeredAt,
                idosoId: lembrete.idosoId ?? _loadedIdosoId,
                observacao: 'Lembrete sem confirmação até o fim do dia.',
              );
              _eventos.add(evento);
              houveNovoEvento = true;
              if (_canSyncIdosoId(evento.idosoId)) {
                pendingSyncWrites.add(
                  OfflineWrite(
                    id: 'queue_$eventId',
                    collection: 'lembrete_eventos',
                    docId: eventId,
                    action: OfflineWriteAction.set,
                    data: evento.toJson(),
                  ),
                );
              }
            }
            missedDate = DateTime(
              missedDate.year,
              missedDate.month,
              missedDate.day + 1,
            );
          }
        }

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

          final originalHour =
              lembrete.originalHorarioHour ?? lembrete.horarioHour;
          final originalMinute =
              lembrete.originalHorarioMinute ?? lembrete.horarioMinute;
          final horarioMudou =
              lembrete.horarioHour != originalHour ||
              lembrete.horarioMinute != originalMinute;

          if (isRecorrente &&
              (lembrete.concluido ||
                  lembrete.concluidoComFoto ||
                  lembrete.status == LembreteStatus.adiado ||
                  horarioMudou)) {
            _lembretes[i] = lembrete.copyWith(
              horarioHour: originalHour,
              horarioMinute: originalMinute,
              concluido: false,
              concluidoComFoto: false,
              status: LembreteStatus.pendente,
            );
            houveAlteracao = true;

            if (_canSyncIdosoId(_loadedIdosoId)) {
              pendingSyncWrites.add(
                OfflineWrite(
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
                ),
              );
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
        if (houveNovoEvento) {
          _eventos.sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
          await _salvarEventosLocais();
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
    final data = jsonEncode(_lembretes.map((l) => l.toJson()).toList());
    await SecureCacheService.instance.write(
      _lembretesCacheKey(_loadedIdosoId),
      data,
    );
    if (SessionRoleService.isElderly) {
      await SecureCacheService.instance.write(
        _elderlyBackupCacheKey(_loadedIdosoId),
        data,
      );
    }
  }

  Future<void> _salvarEventosLocais() async {
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
        await _cancelarNotificacoesLocais();
      } catch (e) {
        debugPrint('Erro ao limpar notificacoes de lembretes: $e');
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
    if (!_canSyncIdosoId(await _getActiveIdosoId())) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('lembretes')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists || doc.data() == null) return null;
      return Lembrete.fromJson(doc.data()!);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        debugPrint('Não foi possível buscar o lembrete remoto $id: ${e.code}');
      }
      return null;
    } catch (e) {
      debugPrint('Não foi possível buscar o lembrete remoto $id.');
      return null;
    }
  }

  Future<Lembrete?> buscarPorId(String id) async {
    if (id.isEmpty) return null;

    await carregar();
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return null;

    _upsertLocal(lembrete);
    await _salvar();
    return lembrete;
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

    if (_canSyncIdosoId(source.idosoId)) {
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

  void _syncInBackground(Future<void> future, String action) {
    unawaited(
      future.catchError((error, stackTrace) {
        debugPrint('Erro ao sincronizar $action: $error');
      }),
    );
  }

  Future<Lembrete?> _atualizarStatusLocal(
    String id,
    LembreteStatus status, {
    String? observacao,
  }) async {
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return null;
    if (_bloqueiaConclusaoSemFoto(lembrete, status)) return null;

    final atualizado = lembrete.copyWith(status: status);
    _upsertLocal(atualizado);
    await _salvar();
    await _registrarEventoLocal(atualizado, status, observacao: observacao);
    return atualizado;
  }

  Future<void> _registrarEventoLocal(
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
  }

  Future<void> _sincronizarEvento(
    Lembrete lembrete,
    LembreteStatus status, {
    String? observacao,
  }) async {
    final source = lembrete.idosoId == null
        ? lembrete.copyWith(idosoId: await _getActiveIdosoId())
        : lembrete;
    if (!_canSyncIdosoId(source.idosoId)) return;

    final evento = _eventos.firstWhere(
      (item) =>
          item.lembreteId == source.id &&
          item.status == status &&
          item.observacao == observacao,
      orElse: () => LembreteEvento.fromLembrete(
        source,
        status: status,
        observacao: observacao,
      ),
    );

    await OfflineSyncService.instance.setOrQueue(
      'lembrete_eventos',
      evento.id,
      evento.toJson(),
    );
  }

  Future<void> _sincronizarStatus(
    Lembrete lembrete,
    LembreteStatus status, {
    String? observacao,
  }) async {
    if (_canSyncIdosoId(lembrete.idosoId)) {
      await OfflineSyncService.instance
          .updateOrQueue('lembretes', lembrete.id, {
            'status': status.storageValue,
            'concluido': status.isConcluido,
            'concluidoComFoto': status == LembreteStatus.concluidoComFoto,
          });
    }
    await _sincronizarEvento(lembrete, status, observacao: observacao);
  }

  Future<Lembrete?> _adiarLocal(String id, int minutos) async {
    final now = DateTime.now().add(Duration(minutes: minutos));
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return null;

    final atualizado = lembrete.copyWith(
      horarioHour: now.hour,
      horarioMinute: now.minute,
      status: LembreteStatus.adiado,
    );
    _upsertLocal(atualizado);
    await _salvar();
    await _registrarEventoLocal(
      atualizado,
      LembreteStatus.adiado,
      observacao: 'Adiado por $minutos minutos',
    );
    return atualizado;
  }

  Future<void> _sincronizarAdiamento(Lembrete lembrete, int minutos) async {
    if (_canSyncIdosoId(lembrete.idosoId)) {
      await OfflineSyncService.instance
          .updateOrQueue('lembretes', lembrete.id, {
            'horarioHour': lembrete.horarioHour,
            'horarioMinute': lembrete.horarioMinute,
            'status': LembreteStatus.adiado.storageValue,
            'concluido': false,
            'concluidoComFoto': false,
          });
    }
    await _sincronizarEvento(
      lembrete,
      LembreteStatus.adiado,
      observacao: 'Adiado por $minutos minutos',
    );
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

    if (_canSyncIdosoId(atualizado.idosoId)) {
      await OfflineSyncService.instance.updateOrQueue(
        'lembretes',
        id,
        remotePatch,
      );
    }
  }

  Future<bool> _checkConnection() async {
    if (SessionRoleService.isElderly) {
      // O modo idoso sempre pode trabalhar localmente. A decisão de enviar
      // ao Firestore é feita separadamente pelo serviço de sincronização.
      return true;
    }

    final canUse = await SessionRoleService.canUseActiveIdoso(
      allowOfflineCache: true,
    );
    if (!canUse) {
      AppStatusService.instance.report(
        id: 'invalid-session',
        title: 'Vinculo nao confirmado',
        message: 'Conecte novamente os aparelhos antes de alterar lembretes.',
        severity: AppStatusSeverity.critical,
      );
    }
    return canUse;
  }

  Future<void> adicionar(Lembrete lembrete) async {
    AppStatusService.instance.clear('offline-sync-permission');
    AppStatusService.instance.clear('offline-sync-pending');
    AppStatusService.instance.clear('offline-sync-failed');
    if (!await _checkConnection()) {
      throw StateError('Vinculo com o idoso nao confirmado.');
    }
    final idosoId = await _getActiveIdosoId();
    final canUploadRemoteMedia =
        !SessionRoleService.isElderly ||
        await SessionRoleService.canSyncElderlyPrivateData();
    final titulo = lembrete.titulo.isEmpty
        ? lembrete.titulo
        : lembrete.titulo[0].toUpperCase() + lembrete.titulo.substring(1);

    String? audioPath = lembrete.audioPath;
    if (audioPath != null) {
      audioPath = await DurableMediaService.instance.preserve(
        audioPath,
        prefix: 'reminder_audio_${lembrete.id}',
      );
    }
    if (canUploadRemoteMedia) {
      try {
        audioPath = await _uploadAudioIfNeeded(
          audioPath: audioPath,
          idosoId: idosoId,
          lembreteId: lembrete.id,
        );
      } catch (e) {
        debugPrint('Áudio mantido localmente para sincronização posterior.');
      }
    }

    String? medicamentoFotoPath = lembrete.medicamentoFotoPath;
    if (medicamentoFotoPath != null) {
      medicamentoFotoPath = await DurableMediaService.instance.preserve(
        medicamentoFotoPath,
        prefix: 'reminder_photo_${lembrete.id}',
      );
    }
    if (canUploadRemoteMedia) {
      try {
        medicamentoFotoPath = await _uploadMedicationPhotoIfNeeded(
          photoPath: medicamentoFotoPath,
          idosoId: idosoId,
          lembreteId: lembrete.id,
        );
      } catch (e) {
        debugPrint('Foto mantida localmente para sincronização posterior.');
      }
    }

    final novo = lembrete.copyWith(
      titulo: titulo,
      idosoId: idosoId,
      audioPath: audioPath,
      medicamentoFotoPath: medicamentoFotoPath,
    );

    _upsertLocal(novo);
    await _salvar();

    if (_canSyncIdosoId(novo.idosoId)) {
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
    if (!_canSyncIdosoId(idosoId) ||
        isRemoteAudioPath(audioPath) ||
        audioPath == 'ia_generated' ||
        audioPath.startsWith('assets/')) {
      return audioPath;
    }

    try {
      return await MediaUploadService.upload(
        localPath: audioPath,
        destinationPath: 'reminder_audio/$idosoId/$lembreteId.m4a',
        contentType: 'audio/mp4',
      );
    } catch (e) {
      if (e is StateError) {
        throw StateError('Arquivo de audio nao encontrado.');
      }
      rethrow;
    }
  }

  Future<String?> _uploadMedicationPhotoIfNeeded({
    required String? photoPath,
    required String idosoId,
    required String lembreteId,
  }) async {
    if (photoPath == null || photoPath.isEmpty) return photoPath;
    if (!_canSyncIdosoId(idosoId) ||
        isRemotePath(photoPath) ||
        photoPath.startsWith('assets/')) {
      return photoPath;
    }

    try {
      return await MediaUploadService.upload(
        localPath: photoPath,
        destinationPath: 'reminder_photos/$idosoId/$lembreteId.jpg',
        contentType: 'image/jpeg',
      );
    } catch (e) {
      if (e is StateError) {
        throw StateError('Foto do medicamento nao encontrada.');
      }
      rethrow;
    }
  }

  Future<bool> concluir(String id) async {
    if (!await _checkConnection()) return false;
    final atualizado = await _atualizarStatusLocal(
      id,
      LembreteStatus.concluido,
    );
    if (atualizado == null) return false;
    _syncInBackground(
      _sincronizarStatus(atualizado, LembreteStatus.concluido),
      'conclusao do lembrete',
    );
    return true;
  }

  Future<void> concluirComFoto(String id, String localPhotoPath) async {
    if (!await _checkConnection()) return;

    final idosoId = await _getActiveIdosoId();
    String finalPath = await DurableMediaService.instance.preserve(
      localPhotoPath,
      prefix: 'confirmation_$id',
    );

    if (_canSyncIdosoId(idosoId) &&
        await SessionRoleService.canSyncElderlyPrivateData()) {
      try {
        finalPath = await MediaUploadService.upload(
          localPath: finalPath,
          destinationPath: 'confirmation_photos/$idosoId/$id.jpg',
          contentType: 'image/jpeg',
        );
      } catch (e) {
        debugPrint('Erro ao fazer upload da foto de confirmacao: $e');
        AppStatusService.instance.report(
          id: 'confirmation-photo-pending',
          title: 'Confirmacao com foto pendente',
          message: 'A foto foi guardada localmente e precisa ser sincronizada.',
          severity: AppStatusSeverity.critical,
        );
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
      await _registrarEvento(
        updated,
        LembreteStatus.concluidoComFoto,
        observacao: 'Medicação confirmada com foto.',
      );
    }
  }

  Future<bool> alternarConclusao(String id) async {
    if (!await _checkConnection()) return false;
    final lembrete = await _findLocalOrRemote(id);
    if (lembrete == null) return false;

    final novoStatus = lembrete.concluido
        ? LembreteStatus.pendente
        : LembreteStatus.concluido;
    final atualizado = await _atualizarStatusLocal(id, novoStatus);
    if (atualizado == null) return false;
    _syncInBackground(
      _sincronizarStatus(atualizado, novoStatus),
      'alteracao de status do lembrete',
    );
    return true;
  }

  Future<void> remover(String id) async {
    if (!await _checkConnection()) return;
    final lembrete = await _findLocalOrRemote(id);
    await NotificationService.instance.cancelar(id);
    _lembretes.removeWhere((item) => item.id == id);
    await _salvar();

    if (_canSyncIdosoId(lembrete?.idosoId)) {
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

  Future<bool> adiar(String id, int minutos) async {
    if (!await _checkConnection()) return false;
    final atualizado = await _adiarLocal(id, minutos);
    if (atualizado == null) return false;
    _syncInBackground(
      _sincronizarAdiamento(atualizado, minutos),
      'adiamento do lembrete',
    );
    return true;
  }

  Future<bool> registrarDificuldade(String id, String motivo) async {
    if (!await _checkConnection()) return false;
    final atualizado = await _atualizarStatusLocal(
      id,
      LembreteStatus.precisaDeAjuda,
      observacao: motivo,
    );
    if (atualizado == null) return false;
    _syncInBackground(
      _sincronizarStatus(
        atualizado,
        LembreteStatus.precisaDeAjuda,
        observacao: motivo,
      ),
      'registro de dificuldade',
    );
    return true;
  }

  List<Map<String, String>> getActiveMedicationsWithSchedule() {
    return _lembretes
        .where((l) => l.categoria == 'medicacao')
        .map((l) => {'titulo': l.titulo, 'horario': l.horarioFormatado})
        .toList();
  }

  Future<Map<String, dynamic>?> analyzeMedication({
    required String newMedication,
    required String newMedicationTime,
  }) async {
    if (!_useFirebase) return null;
    try {
      final existing = getActiveMedicationsWithSchedule();

      final callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeMedication',
      );
      final result = await callable.call({
        'newMedication': newMedication,
        'newMedicationTime': newMedicationTime,
        'existingMedications': existing,
      });

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
    } catch (e) {
      debugPrint('Erro ao analisar medicamento: $e');
    }
    return null;
  }

  Future<String> queryMedicationFAQ({
    required String medicationName,
    required String question,
  }) async {
    if (!_useFirebase) return 'Serviço de IA indisponível offline.';
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'queryMedicationFAQ',
      );
      final result = await callable.call({
        'medicationName': medicationName,
        'question': question,
      });

      if (result.data is Map) {
        final data = Map<String, dynamic>.from(result.data as Map);
        return data['answer'] as String? ?? 'Sem resposta.';
      }
    } catch (e) {
      debugPrint('Erro ao consultar bula FAQ: $e');
    }
    return 'Não foi possível consultar a bula no momento.';
  }
}
