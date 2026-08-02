import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/app_message.dart';
import '../models/offline_write.dart';
import '../utils/audio_path_helper.dart';
import '../utils/firebase_helper.dart';
import 'media_upload_service.dart';
import 'offline_sync_service.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';
import 'app_status_service.dart';
import 'durable_media_service.dart';
import 'remote_media_cache_service.dart';

class MessageService {
  MessageService._();
  static final MessageService instance = MessageService._();

  static const _legacyCacheKey = 'app_messages';
  static const _cachePrefix = 'app_messages_';
  final ValueNotifier<List<AppMessage>> notifier = ValueNotifier([]);
  final List<AppMessage> _messages = [];
  bool _loaded = false;
  String? _loadedIdosoId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;
  bool _isMarkingIncomingRead = false;

  List<AppMessage> get messages => List.unmodifiable(_messages);

  int get unreadIncomingCount {
    final currentRole = SessionRoleService.isSupervisor
        ? 'supervisor'
        : 'elderly';
    return _messages
        .where((message) => message.senderRole != currentRole && !message.lido)
        .length;
  }

  bool get _useFirebase => FirebaseHelper.isInitialized;

  bool _canSyncIdosoId(String? idosoId) {
    return _useFirebase && !SessionRoleService.isLocalOnlyIdosoId(idosoId);
  }

  Future<String> getActiveIdosoId() async {
    return SessionRoleService.getActiveIdosoId();
  }

  Future<String> getActiveIdosoName() async {
    final jsonStr = await SecureCacheService.instance.readElderlyProfile();
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final name = data['nome'] as String?;
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    return 'Idoso';
  }

  Future<void> load() async {
    if (SessionRoleService.isSupervisor) {
      final idosoId = await getActiveIdosoId();
      if (SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
        await _messagesSubscription?.cancel();
        _messagesSubscription = null;
        _messages.clear();
        notifier.value = const [];
        _loaded = false;
        _loadedIdosoId = null;
        return;
      }
    }

    final idosoId = await getActiveIdosoId();
    if (_loaded && _loadedIdosoId == idosoId) return;

    if (_loadedIdosoId != null && _loadedIdosoId != idosoId) {
      await _messagesSubscription?.cancel();
      _messages.clear();
      notifier.value = const [];
    }

    _loaded = true;
    _loadedIdosoId = idosoId;
    await _loadLocal(idosoId);

    if (!_canSyncIdosoId(idosoId)) return;
    if (SessionRoleService.isElderly &&
        !await SessionRoleService.canSyncElderlyPrivateData()) {
      _loaded = false;
      return;
    }
    _messagesSubscription = FirebaseFirestore.instance
        .collection('mensagens')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen(
          (snapshot) async {
            final pendingWrites =
                (await OfflineSyncService.instance.loadQueue())
                    .where((write) => write.collection == 'mensagens')
                    .toList();
            final itemsById = <String, AppMessage>{};
            await Future.wait(
              snapshot.docs.map((doc) async {
                final data = <String, dynamic>{'id': doc.id, ...doc.data()};
                if (data['tipo'] == 'audio' && data['audioPath'] is String) {
                  data['audioPath'] = await RemoteMediaCacheService.instance
                      .resolve(data['audioPath'] as String?);
                }
                itemsById[doc.id] = AppMessage.fromJson(data);
              }),
            );

            for (final write in pendingWrites) {
              final data = Map<String, dynamic>.from(write.data);
              final pendingIdosoId =
                  data['idosoId'] as String? ??
                  itemsById[write.docId]?.idosoId ??
                  idosoId;
              if (pendingIdosoId != idosoId) continue;

              if (write.action == OfflineWriteAction.set) {
                itemsById[write.docId] = AppMessage.fromJson(data);
                continue;
              }

              final current = itemsById[write.docId];
              if (current != null &&
                  write.action == OfflineWriteAction.update) {
                itemsById[write.docId] = AppMessage.fromJson(
                  Map<String, dynamic>.from(current.toJson())..addAll(data),
                );
              }
            }

            _messages
              ..clear()
              ..addAll(itemsById.values)
              ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
            await _saveLocal(idosoId);
            notifier.value = List.from(_messages);
            await OfflineSyncService.instance.syncPendingWrites();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Erro ao escutar mensagens no Firestore: $error');
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              _messagesSubscription?.cancel();
              _messagesSubscription = null;
            }
          },
        );
  }

  Future<void> reset() async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _messages.clear();
    notifier.value = const [];
    _loaded = false;
    _loadedIdosoId = null;
  }

  Future<bool> _checkConnection() async {
    final canUse = await SessionRoleService.canUseActiveIdoso(
      allowOfflineCache: true,
    );
    if (!canUse) {
      AppStatusService.instance.report(
        id: 'messages-invalid-session',
        title: 'Mensagens bloqueadas',
        message:
            'Confirme o vinculo entre os aparelhos antes de enviar mensagens.',
        severity: AppStatusSeverity.critical,
      );
    }
    return canUse;
  }

  Future<bool> sendText(String text) async {
    if (!await _checkConnection()) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final idosoId = await getActiveIdosoId();
    final message = AppMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      idosoId: idosoId,
      nomeIdoso: await getActiveIdosoName(),
      senderRole: SessionRoleService.isSupervisor ? 'supervisor' : 'elderly',
      tipo: 'texto',
      texto: trimmed,
      criadoEm: DateTime.now(),
    );
    await _saveOutgoingLocal(message);
    OfflineSyncService.instance.markMessagePending(message.id);
    unawaited(_sendOutgoingRemote(message));
    return true;
  }

  Future<bool> sendLocation(String text, String mapsUrl) async {
    if (!await _checkConnection()) return false;
    final trimmedText = text.trim();
    final trimmedUrl = mapsUrl.trim();
    if (trimmedUrl.isEmpty) return false;

    final idosoId = await getActiveIdosoId();
    final message = AppMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      idosoId: idosoId,
      nomeIdoso: await getActiveIdosoName(),
      senderRole: SessionRoleService.isSupervisor ? 'supervisor' : 'elderly',
      tipo: 'localizacao',
      texto: trimmedText,
      audioPath: trimmedUrl,
      criadoEm: DateTime.now(),
    );
    await _saveOutgoingLocal(message);
    OfflineSyncService.instance.markMessagePending(message.id);
    unawaited(_sendOutgoingRemote(message));
    return true;
  }

  Future<bool> sendAudio({
    required String audioPath,
    required String fallbackText,
    int? duracaoSegundos,
    String? nomeIdoso,
  }) async {
    if (!await _checkConnection()) return false;
    final idosoId = await getActiveIdosoId();
    final messageId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    String storedAudioPath = await DurableMediaService.instance.preserve(
      audioPath,
      prefix: messageId,
    );
    final message = AppMessage(
      id: messageId,
      idosoId: idosoId,
      nomeIdoso: nomeIdoso ?? await getActiveIdosoName(),
      senderRole: SessionRoleService.isSupervisor ? 'supervisor' : 'elderly',
      tipo: 'audio',
      texto: fallbackText,
      audioPath: storedAudioPath,
      criadoEm: DateTime.now(),
      duracaoSegundos: duracaoSegundos,
    );
    await _saveOutgoingLocal(message);
    OfflineSyncService.instance.markMessagePending(messageId);
    unawaited(
      _processAndSendAudioRemote(message, storedAudioPath, idosoId, messageId),
    );
    return true;
  }

  Future<String> _uploadAudioIfNeeded({
    required String audioPath,
    required String idosoId,
    required String messageId,
  }) async {
    if (!_canSyncIdosoId(idosoId) ||
        isRemoteAudioPath(audioPath) ||
        (SessionRoleService.isElderly &&
            !await SessionRoleService.canSyncElderlyPrivateData())) {
      return audioPath;
    }

    try {
      return await MediaUploadService.upload(
        localPath: audioPath,
        destinationPath: 'message_audio/$idosoId/$messageId.m4a',
        contentType: 'audio/mp4',
      );
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Erro ao fazer upload do audio no Web: $e');
        return audioPath;
      }
      rethrow;
    }
  }

  Future<void> deleteMessage(String id) async {
    final idx = _messages.indexWhere((message) => message.id == id);
    if (idx == -1) return;
    final message = _messages[idx];
    _messages.removeAt(idx);
    await _saveLocal(message.idosoId);
    notifier.value = List.from(_messages);

    try {
      if (_useFirebase && _canSyncIdosoId(message.idosoId)) {
        await FirebaseFirestore.instance
            .collection('mensagens')
            .doc(id)
            .delete();
      }
    } catch (e) {
      debugPrint('Erro ao apagar mensagem no Firestore: $e');
    }
  }

  Future<void> _saveOutgoingLocal(AppMessage message) async {
    _upsert(message);
    await _saveLocal(message.idosoId);
    notifier.value = List.from(_messages);
  }

  Future<void> _processAndSendAudioRemote(
    AppMessage message,
    String storedAudioPath,
    String idosoId,
    String messageId,
  ) async {
    String finalAudioPath = storedAudioPath;
    try {
      finalAudioPath = await _uploadAudioIfNeeded(
        audioPath: storedAudioPath,
        idosoId: idosoId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('Erro ao subir audio da mensagem (salvando local): $e');
    }

    final updatedMessage = message.copyWith(audioPath: finalAudioPath);
    await _saveOutgoingLocal(updatedMessage);

    if (isRemoteAudioPath(finalAudioPath)) {
      await _sendOutgoingRemote(updatedMessage);
    } else {
      if (_canSyncIdosoId(message.idosoId)) {
        await OfflineSyncService.instance.updateOrQueue(
          'mensagens',
          updatedMessage.id,
          updatedMessage.toJson(),
        );
      }
    }
  }

  Future<void> _sendOutgoingRemote(AppMessage message) async {
    try {
      if (_canSyncIdosoId(message.idosoId)) {
        await OfflineSyncService.instance.setOrQueue(
          'mensagens',
          message.id,
          message.toJson(),
        );
        await _sendMessagePush(message);
      }
    } finally {
      OfflineSyncService.instance.unmarkMessagePending(message.id);
    }
  }

  Future<void> saveOutgoing(AppMessage message) async {
    await _saveOutgoingLocal(message);
    OfflineSyncService.instance.markMessagePending(message.id);
    unawaited(_sendOutgoingRemote(message));
  }

  Future<void> _sendMessagePush(AppMessage message) async {
    if (SessionRoleService.isElderly &&
        !await SessionRoleService.canSyncElderlyPrivateData()) {
      return;
    }
    final sentBySupervisor = message.senderRole == 'supervisor';
    final targetRole = sentBySupervisor ? 'elderly' : 'supervisor';
    String targetUserId = message.idosoId;

    try {
      if (!sentBySupervisor) {
        final profile = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(message.idosoId)
            .get()
            .timeout(const Duration(seconds: 4));
        final data = profile.data();
        if (data?['status'] != 'active') return;
        targetUserId = data?['supervisorId'] as String? ?? '';
      }
      if (targetUserId.isEmpty) return;

      final title = sentBySupervisor
          ? 'Novo recado do cuidador'
          : 'Novo recado de ${message.nomeIdoso}';
      final body = switch (message.tipo) {
        'audio' => 'Você recebeu um recado de voz.',
        'localizacao' => 'Você recebeu uma localização.',
        _ =>
          message.texto.length > 160
              ? '${message.texto.substring(0, 157)}...'
              : message.texto,
      };

      await FirebaseFunctions.instance.httpsCallable('sendPush').call({
        'targetUserId': targetUserId,
        'targetRole': targetRole,
        'title': title,
        'body': body,
        'data': {
          'type': 'app_message',
          'messageId': message.id,
          'idosoId': message.idosoId,
          'senderRole': message.senderRole,
        },
      });
    } catch (e) {
      debugPrint('Erro ao enviar notificacao do recado: $e');
    }
  }

  Future<void> markRead(String id) async {
    final idx = _messages.indexWhere((message) => message.id == id);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(lido: true);
    await _saveLocal(_messages[idx].idosoId);
    notifier.value = List.from(_messages);

    if (_canSyncIdosoId(_messages[idx].idosoId)) {
      await OfflineSyncService.instance.updateOrQueue('mensagens', id, {
        'lido': true,
      });
    }
  }

  Future<void> markIncomingMessagesRead() async {
    if (_isMarkingIncomingRead) return;
    final currentRole = SessionRoleService.isSupervisor
        ? 'supervisor'
        : 'elderly';
    final unreadIndexes = <int>[];
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.senderRole != currentRole && !message.lido) {
        unreadIndexes.add(i);
      }
    }
    if (unreadIndexes.isEmpty) return;

    _isMarkingIncomingRead = true;
    try {
      final changed = <AppMessage>[];
      for (final index in unreadIndexes) {
        final updated = _messages[index].copyWith(lido: true);
        _messages[index] = updated;
        changed.add(updated);
      }
      await _saveLocal(_loadedIdosoId ?? changed.first.idosoId);
      notifier.value = List.from(_messages);

      for (final message in changed) {
        if (_canSyncIdosoId(message.idosoId)) {
          await OfflineSyncService.instance.updateOrQueue(
            'mensagens',
            message.id,
            {'lido': true},
          );
        }
      }
    } finally {
      _isMarkingIncomingRead = false;
    }
  }

  String _cacheKeyFor(String idosoId) => '$_cachePrefix$idosoId';

  Future<List<dynamic>?> _readListCache(List<String> keys) async {
    for (final key in keys) {
      final raw = await SecureCacheService.instance.read(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
        debugPrint('Cache de mensagens em $key nao contem uma lista.');
      } catch (e) {
        debugPrint('Cache de mensagens corrompido em $key. Removendo: $e');
      }
      await SecureCacheService.instance.delete(key);
    }
    return null;
  }

  Future<void> _loadLocal(String idosoId) async {
    if (SessionRoleService.isSupervisor) return;
    final list = await _readListCache([_cacheKeyFor(idosoId), _legacyCacheKey]);
    if (list != null) {
      final messages = <AppMessage>[];
      for (final item in list) {
        try {
          final message = AppMessage.fromJson(item as Map<String, dynamic>);
          if (message.idosoId == idosoId) messages.add(message);
        } catch (e) {
          debugPrint('Mensagem local invalida ignorada: $e');
        }
      }
      _messages
        ..clear()
        ..addAll(messages)
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    }
    notifier.value = List.from(_messages);
  }

  Future<void> _saveLocal(String idosoId) async {
    if (SessionRoleService.isSupervisor) return;
    await SecureCacheService.instance.write(
      _cacheKeyFor(idosoId),
      jsonEncode(
        _messages
            .where((message) => message.idosoId == idosoId)
            .map((message) => message.toJson())
            .toList(),
      ),
    );
  }

  void _upsert(AppMessage message) {
    final idx = _messages.indexWhere((item) => item.id == message.id);
    if (idx == -1) {
      _messages.insert(0, message);
    } else {
      _messages[idx] = message;
    }
    _messages.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  }
}
