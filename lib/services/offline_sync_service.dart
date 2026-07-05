import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_write.dart';

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const _queueKey = 'offline_write_queue';
  static const _writeTimeout = Duration(seconds: 6);
  static const _autoSyncInterval = Duration(seconds: 30);
  static const _syncSoonDelay = Duration(seconds: 5);

  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  bool _syncing = false;
  bool _autoSyncStarted = false;
  Timer? _autoSyncTimer;
  Timer? _syncSoonTimer;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<OfflineWrite>> loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) {
      pendingCount.value = 0;
      return <OfflineWrite>[];
    }

    final list = jsonDecode(raw) as List;
    final writes = list
        .map((item) => OfflineWrite.fromJson(item as Map<String, dynamic>))
        .toList();
    pendingCount.value = writes.length;
    return writes;
  }

  Future<void> enqueue({
    required String collection,
    required String docId,
    required OfflineWriteAction action,
    Map<String, dynamic> data = const {},
  }) async {
    final queue = await loadQueue();
    final write = OfflineWrite(
      id: '${DateTime.now().microsecondsSinceEpoch}_${queue.length}',
      collection: collection,
      docId: docId,
      action: action,
      data: data,
    );
    queue.add(write);
    await _saveQueue(_compact(queue));
    _scheduleSyncSoon();
  }

  Future<void> startAutoSync() async {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    await loadQueue();
    unawaited(syncPendingWrites());
    _autoSyncTimer = Timer.periodic(
      _autoSyncInterval,
      (_) => syncPendingWrites(),
    );
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _syncSoonTimer?.cancel();
    _autoSyncStarted = false;
  }

  Future<bool> setOrQueue(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    return _runOrQueue(
      collection: collection,
      docId: docId,
      action: OfflineWriteAction.set,
      data: data,
    );
  }

  Future<bool> updateOrQueue(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    return _runOrQueue(
      collection: collection,
      docId: docId,
      action: OfflineWriteAction.update,
      data: data,
    );
  }

  Future<bool> deleteOrQueue(String collection, String docId) async {
    return _runOrQueue(
      collection: collection,
      docId: docId,
      action: OfflineWriteAction.delete,
    );
  }

  Future<bool> _runOrQueue({
    required String collection,
    required String docId,
    required OfflineWriteAction action,
    Map<String, dynamic> data = const {},
  }) async {
    if (_useFirebase) {
      try {
        await _apply(
          OfflineWrite(
            id: 'direct_${DateTime.now().microsecondsSinceEpoch}',
            collection: collection,
            docId: docId,
            action: action,
            data: data,
          ),
        ).timeout(_writeTimeout);
        unawaited(syncPendingWrites());
        return true;
      } catch (e) {
        debugPrint('Escrita offline enfileirada em $collection/$docId: $e');
      }
    }

    await enqueue(
      collection: collection,
      docId: docId,
      action: action,
      data: data,
    );
    return false;
  }

  Future<void> syncPendingWrites() async {
    if (_syncing || !_useFirebase) return;
    _syncing = true;
    try {
      var queue = await loadQueue();
      if (queue.isEmpty) return;

      final remaining = <OfflineWrite>[];
      for (final write in queue) {
        try {
          await _apply(write).timeout(_writeTimeout);
        } catch (e) {
          debugPrint(
            'Falha ao sincronizar ${write.collection}/${write.docId}: $e',
          );
          remaining.add(write.copyWith(attempts: write.attempts + 1));
        }
      }
      await _saveQueue(_compact(remaining));
    } finally {
      _syncing = false;
    }
  }

  void _scheduleSyncSoon() {
    if (!_useFirebase) return;
    if (_syncSoonTimer?.isActive ?? false) return;
    _syncSoonTimer = Timer(_syncSoonDelay, () {
      unawaited(syncPendingWrites());
    });
  }

  Future<void> _apply(OfflineWrite write) {
    final doc = FirebaseFirestore.instance
        .collection(write.collection)
        .doc(write.docId);

    switch (write.action) {
      case OfflineWriteAction.set:
        return doc.set(write.data, SetOptions(merge: true));
      case OfflineWriteAction.update:
        return doc.update(write.data);
      case OfflineWriteAction.delete:
        return doc.delete();
    }
  }

  Future<void> _saveQueue(List<OfflineWrite> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(queue.map((write) => write.toJson()).toList());
    await prefs.setString(_queueKey, raw);
    pendingCount.value = queue.length;
  }

  List<OfflineWrite> _compact(List<OfflineWrite> queue) {
    final compacted = <OfflineWrite>[];
    final deletedDocs = <String>{};

    for (final write in queue.reversed) {
      final key = '${write.collection}/${write.docId}';
      if (deletedDocs.contains(key)) continue;

      if (write.action == OfflineWriteAction.delete) {
        deletedDocs.add(key);
        compacted.add(write);
        continue;
      }

      compacted.add(write);
    }

    final ordered = compacted.reversed.toList();
    if (ordered.length <= 250) return ordered;
    return ordered.sublist(ordered.length - 250);
  }
}
