import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'session_role_service.dart';

class PresenceStatus {
  final bool isOnline;
  final String statusText;
  final DateTime? lastSeen;

  const PresenceStatus({
    required this.isOnline,
    required this.statusText,
    this.lastSeen,
  });
}

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _heartbeatTimer;
  bool _started = false;

  void startHeartbeat() {
    if (_started) return;
    _started = true;

    // Send immediate heartbeat
    unawaited(updateMyPresence());

    // Send periodic heartbeat every 25 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      updateMyPresence();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _started = false;
  }

  Future<void> updateMyPresence() async {
    try {
      await SessionRoleService.load();

      if (SessionRoleService.isSupervisor) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(uid)
              .set({
                'lastSeen': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      } else {
        final idosoId = await SessionRoleService.getActiveIdosoId();
        if (idosoId.isNotEmpty &&
            !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
          final batch = FirebaseFirestore.instance.batch();
          final perfilRef = FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId);
          batch.set(perfilRef, {
            'lastSeen': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final idosoRef = FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId);
          batch.set(idosoRef, {
            'lastSeen': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar presença (heartbeat): $e');
    }
  }

  Stream<PresenceStatus> watchUserPresence({
    required String userId,
    required bool isSupervisorTarget,
  }) {
    if (userId.isEmpty) {
      return Stream.value(
        const PresenceStatus(isOnline: false, statusText: 'offline'),
      );
    }

    final collectionName = isSupervisorTarget ? 'supervisores' : 'idoso_perfil';

    return FirebaseFirestore.instance
        .collection(collectionName)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) {
            return const PresenceStatus(isOnline: false, statusText: 'offline');
          }

          final data = doc.data()!;
          final rawLastSeen = data['lastSeen'];

          DateTime? lastSeen;
          if (rawLastSeen is Timestamp) {
            lastSeen = rawLastSeen.toDate();
          } else if (rawLastSeen is String) {
            lastSeen = DateTime.tryParse(rawLastSeen);
          }

          if (lastSeen == null) {
            return const PresenceStatus(isOnline: false, statusText: 'offline');
          }

          final now = DateTime.now();
          final diffSeconds = now.difference(lastSeen).inSeconds;

          // Online if lastSeen is within the last 120 seconds
          final isOnline = diffSeconds < 120;
          final text = formatPresenceText(lastSeen, isOnline: isOnline);

          return PresenceStatus(
            isOnline: isOnline,
            statusText: text,
            lastSeen: lastSeen,
          );
        });
  }

  static String formatPresenceText(
    DateTime lastSeen, {
    required bool isOnline,
  }) {
    if (isOnline) return 'Online';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final seenDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);

    final hourStr = lastSeen.hour.toString().padLeft(2, '0');
    final minStr = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minStr';

    if (seenDate == today) {
      return 'Visto por último hoje às $timeStr';
    } else if (seenDate == yesterday) {
      return 'Visto por último ontem às $timeStr';
    } else {
      final dayStr = lastSeen.day.toString().padLeft(2, '0');
      final monthStr = lastSeen.month.toString().padLeft(2, '0');
      return 'Visto por último em $dayStr/$monthStr às $timeStr';
    }
  }
}
