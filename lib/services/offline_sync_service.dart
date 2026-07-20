import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/firebase_helper.dart';
import 'media_upload_service.dart';

import '../models/offline_write.dart';
import 'app_status_service.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const _queueKeyPrefix = 'offline_write_queue';
  static const _writeTimeout = Duration(seconds: 6);
  static const _autoSyncInterval = Duration(seconds: 30);
  static const _syncSoonDelay = Duration(seconds: 5);

  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<Set<String>> pendingMessageIds = ValueNotifier(
    <String>{},
  );
  bool _syncing = false;
  bool _autoSyncStarted = false;
  Timer? _autoSyncTimer;
  Timer? _syncSoonTimer;
  Timer? _backoffTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  Future<bool> _canAttemptRemoteSync() async {
    if (!_useFirebase) return false;
    if (!SessionRoleService.isElderly) return true;
    return SessionRoleService.canSyncElderlyPrivateData();
  }

  Future<String> _queueKey() async {
    final idosoId = await SessionRoleService.getActiveIdosoId();
    final role = SessionRoleService.activeRole ?? 'unknown';
    String userId = 'anonymous';
    if (_useFirebase) {
      userId = FirebaseAuth.instance.currentUser?.uid ?? userId;
    }
    return '${_queueKeyPrefix}_${role}_${userId}_$idosoId';
  }

  Future<List<OfflineWrite>> loadQueue() async {
    final queueKey = await _queueKey();
    final raw = await SecureCacheService.instance.read(queueKey);
    if (raw == null || raw.isEmpty) {
      pendingCount.value = 0;
      pendingMessageIds.value = <String>{};
      return <OfflineWrite>[];
    }

    List<OfflineWrite> writes;
    try {
      final list = jsonDecode(raw) as List;
      writes = <OfflineWrite>[];
      for (final item in list) {
        try {
          writes.add(OfflineWrite.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Escrita offline invalida ignorada: $e');
        }
      }
    } catch (e) {
      debugPrint('Fila offline corrompida. Removendo cache local: $e');
      await SecureCacheService.instance.delete(queueKey);
      pendingCount.value = 0;
      pendingMessageIds.value = <String>{};
      return <OfflineWrite>[];
    }
    _updatePendingNotifiers(writes);
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

  Future<void> enqueueMultiple(List<OfflineWrite> writes) async {
    final queue = await loadQueue();
    queue.addAll(writes);
    await _saveQueue(_compact(queue));
    _scheduleSyncSoon();
  }

  Future<void> startAutoSync() async {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    await loadQueue();
    unawaited(syncPendingWrites());
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _backoffTimer?.cancel();
        _backoffTimer = null;
        unawaited(_retryTransientWritesAndSync());
      }
    });
    _autoSyncTimer = Timer.periodic(
      _autoSyncInterval,
      (_) => syncPendingWrites(),
    );
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _syncSoonTimer?.cancel();
    _backoffTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
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
    if (!await _canAttemptRemoteSync()) {
      await enqueue(
        collection: collection,
        docId: docId,
        action: action,
        data: data,
      );
      return false;
    }
    final queue = await loadQueue();
    if (queue.isEmpty && _useFirebase) {
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
    if (_syncing || !_useFirebase || (_backoffTimer?.isActive ?? false)) return;
    if (!await _canAttemptRemoteSync()) return;
    AppStatusService.instance.clear('offline-sync-permission');
    AppStatusService.instance.clear('offline-sync-pending');
    AppStatusService.instance.clear('offline-sync-failed');
    _syncing = true;
    try {
      var queue = await loadQueue();
      if (queue.isEmpty) return;

      final remaining = <OfflineWrite>[];
      bool hasFailure = false;

      for (final write in queue) {
        if (write.failed || write.attempts >= 10) {
          debugPrint(
            'Descartando escrita offline permanentemente falha: ${write.collection}/${write.docId}',
          );
          continue; // Do NOT add to remaining
        }

        if (hasFailure) {
          remaining.add(write);
          continue;
        }

        if (_isLocalOnlyWrite(write)) {
          continue;
        }

        try {
          final updatedWrite = await _uploadPendingFilesIfNeeded(write);
          await _apply(updatedWrite).timeout(_writeTimeout);
        } catch (e) {
          final permissionDenied = _isPermissionDenied(e);
          final newAttempts = write.attempts + 1;

          if (permissionDenied || newAttempts >= 10) {
            debugPrint(
              'Escrita bloqueada permanentemente (permissao negada ou limite de tentativas): ${write.collection}/${write.docId}',
            );
            AppStatusService.instance.clear('offline-sync-pending');
            // Do not add to remaining, discard it.
          } else {
            debugPrint(
              'Falha temporária ao sincronizar ${write.collection}/${write.docId}: $e',
            );
            remaining.add(
              write.copyWith(
                attempts: newAttempts,
                failed: false,
                lastError: e.toString(),
              ),
            );
            _scheduleBackoff(newAttempts);
            hasFailure = true;
          }
        }
      }

      final freshQueue = await loadQueue();
      final newlyAdded = freshQueue
          .where((w) => !queue.any((q) => q.id == w.id))
          .toList();
      remaining.addAll(newlyAdded);

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

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return true;
    }
    return error.toString().contains('permission-denied');
  }

  void _scheduleBackoff(int attempts) {
    if (_backoffTimer?.isActive ?? false) return;
    final exponent = attempts.clamp(0, 8);
    final seconds = (5 * (1 << exponent)).clamp(10, 1800);
    _backoffTimer = Timer(Duration(seconds: seconds), () {
      _backoffTimer = null;
      unawaited(syncPendingWrites());
    });
  }

  Future<void> _retryTransientWritesAndSync() async {
    final queue = await loadQueue();
    final reset = queue.map((write) {
      final permissionError =
          write.lastError?.contains('permission-denied') ?? false;
      if (write.failed && !permissionError) {
        return write.copyWith(failed: false, attempts: 0, lastError: '');
      }
      return write;
    }).toList();
    await _saveQueue(_compact(reset));
    await syncPendingWrites();
  }

  bool _isLocalOnlyWrite(OfflineWrite write) {
    if (!write.data.containsKey('idosoId')) return false;
    final idosoId = write.data['idosoId'] as String?;
    return SessionRoleService.isLocalOnlyIdosoId(idosoId);
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
    final raw = jsonEncode(queue.map((write) => write.toJson()).toList());
    await SecureCacheService.instance.write(await _queueKey(), raw);
    _updatePendingNotifiers(queue);
  }

  void _updatePendingNotifiers(List<OfflineWrite> queue) {
    final pending = queue.where((write) => !write.failed).toList();
    pendingCount.value = pending.length;
    pendingMessageIds.value = pending
        .where((write) => write.collection == 'mensagens')
        .map((write) => write.docId)
        .toSet();
  }

  Future<void> retryFailedWrites() async {
    final queue = await loadQueue();
    final retriable = queue
        .map(
          (write) => write.failed
              ? write.copyWith(failed: false, attempts: 0, lastError: '')
              : write,
        )
        .toList();
    await _saveQueue(_compact(retriable));
    AppStatusService.instance.clear('offline-sync-failed');
    await syncPendingWrites();
  }

  List<OfflineWrite> _compact(List<OfflineWrite> queue) {
    final compactedMap = <String, OfflineWrite>{};
    final deletedDocs = <String>{};

    for (final write in queue.reversed) {
      final key = '${write.collection}/${write.docId}';
      if (deletedDocs.contains(key)) continue;

      if (write.action == OfflineWriteAction.delete) {
        deletedDocs.add(key);
        compactedMap[key] = write;
        continue;
      }

      if (write.action == OfflineWriteAction.update) {
        final existing = compactedMap[key];
        if (existing != null) {
          if (existing.action == OfflineWriteAction.update) {
            final mergedData = Map<String, dynamic>.from(write.data)
              ..addAll(existing.data);
            compactedMap[key] = existing.copyWith(data: mergedData);
          } else if (existing.action == OfflineWriteAction.set) {
            final mergedData = Map<String, dynamic>.from(write.data)
              ..addAll(existing.data);
            compactedMap[key] = existing.copyWith(data: mergedData);
          }
          continue;
        }
      }

      if (write.action == OfflineWriteAction.set) {
        final existing = compactedMap[key];
        if (existing != null) {
          if (existing.action == OfflineWriteAction.update) {
            final mergedData = Map<String, dynamic>.from(write.data)
              ..addAll(existing.data);
            compactedMap[key] = write.copyWith(
              action: OfflineWriteAction.set,
              data: mergedData,
            );
          }
          continue;
        }
      }

      compactedMap[key] = write;
    }

    final result = <OfflineWrite>[];
    for (final write in queue) {
      final key = '${write.collection}/${write.docId}';
      final comp = compactedMap[key];
      if (comp != null && !result.contains(comp)) {
        result.add(comp);
      }
    }
    return result;
  }

  bool _isRemotePath(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _isUploadableLocalPath(String path) {
    return path.isNotEmpty &&
        !_isRemotePath(path) &&
        path != 'ia_generated' &&
        !path.startsWith('assets/');
  }

  Future<OfflineWrite> _uploadPendingFilesIfNeeded(OfflineWrite write) async {
    if (write.collection == 'lembretes') {
      final data = Map<String, dynamic>.from(write.data);
      final idosoId =
          data['idosoId'] as String? ??
          await SessionRoleService.getActiveIdosoId();
      final lembreteId = write.docId;

      final audioPath = data['audioPath'] as String?;
      if (audioPath != null && _isUploadableLocalPath(audioPath)) {
        final remoteUrl = await _uploadToStorage(
          localPath: audioPath,
          destinationPath: 'reminder_audio/$idosoId/$lembreteId.m4a',
          contentType: 'audio/mp4',
        );
        if (remoteUrl != null) {
          data['audioPath'] = remoteUrl;
        }
      }

      final fotoPath = data['medicamentoFotoPath'] as String?;
      if (fotoPath != null && _isUploadableLocalPath(fotoPath)) {
        final isConfirmation =
            data['status'] == 'concluido_com_foto' ||
            (write.action == OfflineWriteAction.update &&
                data['concluidoComFoto'] == true);
        final folder = isConfirmation
            ? 'confirmation_photos'
            : 'reminder_photos';
        final remoteUrl = await _uploadToStorage(
          localPath: fotoPath,
          destinationPath: '$folder/$idosoId/$lembreteId.jpg',
          contentType: 'image/jpeg',
        );
        if (remoteUrl != null) {
          data['medicamentoFotoPath'] = remoteUrl;
        }
      }

      return write.copyWith(data: data);
    }

    if (write.collection == 'mensagens') {
      final data = Map<String, dynamic>.from(write.data);
      final idosoId =
          data['idosoId'] as String? ??
          await SessionRoleService.getActiveIdosoId();
      final messageId = write.docId;

      final audioPath = data['audioPath'] as String?;
      if (audioPath != null && _isUploadableLocalPath(audioPath)) {
        final remoteUrl = await _uploadToStorage(
          localPath: audioPath,
          destinationPath: 'message_audio/$idosoId/$messageId.m4a',
          contentType: 'audio/mp4',
        );
        if (remoteUrl != null) {
          data['audioPath'] = remoteUrl;
        }
      }

      return write.copyWith(data: data);
    }

    if (write.collection == 'idosos' || write.collection == 'idoso_perfil') {
      final data = Map<String, dynamic>.from(write.data);
      final photoPath = data['fotoPath'] as String?;
      if (photoPath != null && _isUploadableLocalPath(photoPath)) {
        final remoteUrl = await _uploadToStorage(
          localPath: photoPath,
          destinationPath: 'perfis/${write.docId}/profile.jpg',
          contentType: 'image/jpeg',
        );
        if (remoteUrl != null) data['fotoPath'] = remoteUrl;
      }
      return write.copyWith(data: data);
    }

    return write;
  }

  Future<String?> _uploadToStorage({
    required String localPath,
    required String destinationPath,
    required String contentType,
  }) async {
    return MediaUploadService.upload(
      localPath: localPath,
      destinationPath: destinationPath,
      contentType: contentType,
    );
  }

  Future<Set<String>> getPendingDeletes(String collection) async {
    final queue = await loadQueue();
    return queue
        .where(
          (w) =>
              !w.failed &&
              w.collection == collection &&
              w.action == OfflineWriteAction.delete,
        )
        .map((w) => w.docId)
        .toSet();
  }
}
