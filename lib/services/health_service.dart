import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'offline_sync_service.dart';
import 'session_role_service.dart';

class HealthService {
  HealthService._();
  static final HealthService _instance = HealthService._();
  static HealthService get instance => _instance;

  final StreamController<int?> _localBpmController =
      StreamController<int?>.broadcast();

  Stream<int?> get bpmStream => _localBpmController.stream;

  List<int> _bpmHistory = [];
  List<int> get bpmHistory => List.unmodifiable(_bpmHistory);

  static bool isValidBpm(int? bpm) => bpm != null && bpm >= 40 && bpm <= 180;

  Future<int?> getLastBpm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_bpm_value');
  }

  Future<String?> getLastBpmTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_bpm_time');
  }

  Future<List<int>> loadBpmHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('bpm_history');
      if (historyStr != null) {
        final list = historyStr.split(',').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        _bpmHistory = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}
    return [];
  }

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

  Future<void> enviarMetricas(int bpm) async {
    if (SessionRoleService.isSupervisor) {
      debugPrint('Supervisores nao podem enviar metricas de saude.');
      return;
    }
    if (!isValidBpm(bpm)) {
      debugPrint('BPM invalido ignorado: $bpm');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_bpm_value', bpm);
      await prefs.setString('last_bpm_time', DateTime.now().toIso8601String());

      final historyStr = prefs.getString('bpm_history');
      final history = <int>[];
      if (historyStr != null) {
        final parts = historyStr.split(',').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        history.addAll(parts);
      }
      history.add(bpm);
      if (history.length > 50) history.removeAt(0);
      await prefs.setString('bpm_history', history.join(','));
      _bpmHistory = history;
    } catch (_) {}

    _localBpmController.add(bpm);

    if (_useFirebase) {
      try {
        final idosoId = await _getActiveIdosoId();
        await OfflineSyncService.instance.setOrQueue(
          'health_metrics',
          idosoId,
          {'bpm': bpm, 'time': DateTime.now().toIso8601String()},
        );
      } catch (e) {
        debugPrint('Erro ao enviar batimentos para o Firestore: $e');
      }
    }
  }

  Stream<int?> obterMetricasStream() {
    if (_useFirebase) {
      return (() async* {
        if (SessionRoleService.isSupervisor) {
          final connected = await SessionRoleService.isSupervisorConnected();
          if (!connected) {
            yield null;
            return;
          }
        }
        final idosoId = await _getActiveIdosoId();
        yield* FirebaseFirestore.instance
            .collection('health_metrics')
            .doc(idosoId)
            .snapshots()
            .asyncMap((snapshot) async {
              if (SessionRoleService.isSupervisor) {
                final connected = await SessionRoleService.isSupervisorConnected();
                if (!connected) return null;
              }
              if (snapshot.exists && snapshot.data() != null) {
                final bpm = snapshot.data()!['bpm'] as int?;
                return isValidBpm(bpm) ? bpm : null;
              }
              return null;
            });
      })();
    } else {
      return _localBpmController.stream;
    }
  }

}
