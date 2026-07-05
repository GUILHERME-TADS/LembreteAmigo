import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_message.dart';
import '../utils/audio_path_helper.dart';
import 'offline_sync_service.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';

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

  List<AppMessage> get messages => List.unmodifiable(_messages);

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> getActiveIdosoId() async {
    return SessionRoleService.getActiveIdosoId();
  }

  Future<String> getActiveIdosoName() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('idoso_perfil');
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

    if (!_useFirebase) return;
    _messagesSubscription = FirebaseFirestore.instance
        .collection('mensagens')
        .where('idosoId', isEqualTo: idosoId)
        .snapshots()
        .listen((snapshot) async {
          _messages
            ..clear()
            ..addAll(
              snapshot.docs.map((doc) {
                final data = doc.data();
                return AppMessage.fromJson({'id': doc.id, ...data});
              }),
            )
            ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
          await _saveLocal(idosoId);
          notifier.value = List.from(_messages);
          await OfflineSyncService.instance.syncPendingWrites();
        }, onError: (Object error, StackTrace stackTrace) {
          debugPrint('Erro ao escutar mensagens no Firestore: $error');
        });
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

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
    await saveOutgoing(message);
  }

  Future<void> sendAudio({
    required String audioPath,
    required String fallbackText,
    String? nomeIdoso,
  }) async {
    final idosoId = await getActiveIdosoId();
    final messageId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final storedAudioPath = await _uploadAudioIfNeeded(
      audioPath: audioPath,
      idosoId: idosoId,
      messageId: messageId,
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
    );
    await saveOutgoing(message);
  }

  Future<String> _uploadAudioIfNeeded({
    required String audioPath,
    required String idosoId,
    required String messageId,
  }) async {
    if (!_useFirebase || isRemoteAudioPath(audioPath)) return audioPath;

    final file = File(audioPath);
    if (!await file.exists()) {
      throw StateError('Arquivo de audio nao encontrado.');
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('message_audio')
        .child(idosoId)
        .child('$messageId.m4a');
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/mp4'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> saveOutgoing(AppMessage message) async {
    _upsert(message);
    await _saveLocal(message.idosoId);
    notifier.value = List.from(_messages);

    if (_useFirebase) {
      await OfflineSyncService.instance.setOrQueue(
        'mensagens',
        message.id,
        message.toJson(),
      );
    }
  }

  Future<void> markRead(String id) async {
    final idx = _messages.indexWhere((message) => message.id == id);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(lido: true);
    await _saveLocal(_messages[idx].idosoId);
    notifier.value = List.from(_messages);

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue('mensagens', id, {
        'lido': true,
      });
    }
  }

  String _cacheKeyFor(String idosoId) => '$_cachePrefix$idosoId';

  Future<List<dynamic>?> _readListCache(
    List<String> keys,
  ) async {
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
    final list = await _readListCache([
      _cacheKeyFor(idosoId),
      _legacyCacheKey,
    ]);
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
