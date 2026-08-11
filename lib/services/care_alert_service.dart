import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/care_alert.dart';
import '../utils/firebase_helper.dart';

class CareAlertService {
  CareAlertService._();
  static final CareAlertService instance = CareAlertService._();

  Stream<List<CareAlert>> watchAlerts(String elderlyId) {
    if (!FirebaseHelper.isInitialized || elderlyId.isEmpty) {
      return Stream.value(const <CareAlert>[]);
    }
    return FirebaseFirestore.instance
        .collection('alertas')
        .where('idosoId', isEqualTo: elderlyId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CareAlert.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> acknowledge(String alertId) async {
    await FirebaseFunctions.instance.httpsCallable('acknowledgeCareAlert').call(
      {'alertId': alertId},
    );
  }

  Future<void> resolve(String alertId, {String resolution = ''}) async {
    await FirebaseFunctions.instance.httpsCallable('resolveCareAlert').call({
      'alertId': alertId,
      'resolution': resolution.trim(),
    });
  }
}
