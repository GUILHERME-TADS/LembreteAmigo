import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final superDocs = await FirebaseFirestore.instance
      .collection('supervisores')
      .get();
  debugPrint('Supervisors count: ${superDocs.docs.length}');
  for (var d in superDocs.docs) {
    debugPrint('Supervisor ID: ${d.id}');
  }
  final idososDocs = await FirebaseFirestore.instance
      .collection('idoso_perfil')
      .get();
  debugPrint('Idosos Profiles count: ${idososDocs.docs.length}');
  for (var d in idososDocs.docs) {
    debugPrint(
      'Idoso ID: ${d.id}, SupervisorId: ${d.data()['supervisorId']}, Status: ${d.data()['status']}',
    );
    final lembretes = await FirebaseFirestore.instance
        .collection('lembretes')
        .where('idosoId', isEqualTo: d.id)
        .get();
    debugPrint('  -> Lembretes count: ${lembretes.docs.length}');
  }
}
