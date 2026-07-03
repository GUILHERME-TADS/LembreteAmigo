import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_message.dart';
import 'offline_sync_service.dart';
import 'session_role_service.dart';

class MessageService {
  MessageService._();
  static final MessageService instance = MessageService._();

  static const _cacheKey = 'app_messages';
  final ValueNotifier<List<AppMessage>> notifier = ValueNotifier([]);
  final List<AppMessage> _messages = [];
  bool _loaded = false;

  List<AppMessage> get messages => List.unmodifiable(_messages);

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> getActiveIdosoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_idoso_id') ??
        prefs.getString('paired_idoso_id') ??
        'joao';
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
    if (_loaded) return;
    _loaded = true;
    await _loadLocal();

    if (!_useFirebase) return;
    final idosoId = await getActiveIdosoId();
    FirebaseFirestore.instance
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
          await _saveLocal();
          notifier.value = List.from(_messages);
          await OfflineSyncService.instance.syncPendingWrites();
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
    final message = AppMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      idosoId: idosoId,
      nomeIdoso: nomeIdoso ?? await getActiveIdosoName(),
      senderRole: SessionRoleService.isSupervisor ? 'supervisor' : 'elderly',
      tipo: 'audio',
      texto: fallbackText,
      audioPath: audioPath,
      criadoEm: DateTime.now(),
    );
    await saveOutgoing(message);
  }

  Future<void> saveOutgoing(AppMessage message) async {
    _upsert(message);
    await _saveLocal();
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
    await _saveLocal();
    notifier.value = List.from(_messages);

    if (_useFirebase) {
      await OfflineSyncService.instance.updateOrQueue('mensagens', id, {
        'lido': true,
      });
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _messages
        ..clear()
        ..addAll(
          list.map((item) => AppMessage.fromJson(item as Map<String, dynamic>)),
        )
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    }
    notifier.value = List.from(_messages);
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(_messages.map((message) => message.toJson()).toList()),
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
