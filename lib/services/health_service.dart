import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'offline_sync_service.dart';

class HealthService {
  HealthService._();
  static final HealthService _instance = HealthService._();
  static HealthService get instance => _instance;

  final StreamController<int> _localBpmController =
      StreamController<int>.broadcast();

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

  Future<void> enviarMetricas(int bpm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_bpm_value', bpm);
      await prefs.setString('last_bpm_time', DateTime.now().toIso8601String());
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

  Stream<int> obterMetricasStream() {
    if (_useFirebase) {
      final controller = StreamController<int>.broadcast();
      _getActiveIdosoId().then((idosoId) {
        FirebaseFirestore.instance
            .collection('health_metrics')
            .doc(idosoId)
            .snapshots()
            .listen(
              (snapshot) {
                if (snapshot.exists && snapshot.data() != null) {
                  controller.add(snapshot.data()!['bpm'] as int? ?? 72);
                } else {
                  controller.add(72);
                }
              },
              onError: (err) {
                controller.addError(err);
              },
            );
      });
      return controller.stream;
    } else {
      return _localBpmController.stream;
    }
  }
}
