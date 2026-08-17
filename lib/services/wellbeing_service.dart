import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/wellbeing_entry.dart';
import '../utils/firebase_helper.dart';
import 'secure_cache_service.dart';
import 'session_role_service.dart';

class WellbeingService {
  WellbeingService._();
  static final WellbeingService instance = WellbeingService._();

  static const _localKeyPrefix = 'wellbeing_entries_v1_';

  Stream<List<WellbeingEntry>> watchEntries(String elderlyId) async* {
    if (!FirebaseHelper.isInitialized ||
        SessionRoleService.isLocalOnlyIdosoId(elderlyId)) {
      yield await _loadLocal(elderlyId);
      return;
    }
    yield* FirebaseFirestore.instance
        .collection('bem_estar_registros')
        .where('idosoId', isEqualTo: elderlyId)
        .orderBy('createdAt', descending: true)
        .limit(90)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(WellbeingEntry.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<WellbeingEntry> addEntry({
    required int mood,
    required List<String> symptoms,
    required String note,
    required bool needsHelp,
  }) async {
    final elderlyId = await SessionRoleService.getActiveIdosoId();
    final collection = FirebaseHelper.isInitialized
        ? FirebaseFirestore.instance.collection('bem_estar_registros')
        : null;
    final id =
        collection?.doc().id ??
        'local_${DateTime.now().microsecondsSinceEpoch}';
    final createdBy = FirebaseHelper.isInitialized
        ? FirebaseAuth.instance.currentUser?.uid ?? elderlyId
        : elderlyId;
    final entry = WellbeingEntry(
      id: id,
      elderlyId: elderlyId,
      mood: mood.clamp(1, 5),
      symptoms: symptoms.take(12).toList(growable: false),
      note: note.trim(),
      transcript: note.trim(),
      needsHelp: needsHelp,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    if (collection != null &&
        !SessionRoleService.isLocalOnlyIdosoId(elderlyId)) {
      await collection.doc(id).set(entry.toFirestore());
    } else {
      final current = await _loadLocal(elderlyId);
      await _saveLocal(elderlyId, [entry, ...current].take(90).toList());
    }
    return entry;
  }

  Future<void> logHydration() async {
    await addEntry(
      mood: 4,
      symptoms: const ['Hidratação (+1 copo d\'água)'],
      note: 'Ingestão de água registrada após medicamento.',
      needsHelp: false,
    );
  }

  Future<List<WellbeingEntry>> _loadLocal(String elderlyId) async {
    final raw = await SecureCacheService.instance.read(
      '$_localKeyPrefix$elderlyId',
    );
    if (raw == null || raw.isEmpty) return const [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      final entries = values
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .map((value) => WellbeingEntry.fromMap(value['id'] as String, value))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(String elderlyId, List<WellbeingEntry> entries) {
    return SecureCacheService.instance.write(
      '$_localKeyPrefix$elderlyId',
      jsonEncode(entries.map((entry) => entry.toLocalJson()).toList()),
    );
  }
}
