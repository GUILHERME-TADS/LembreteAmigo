import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../utils/firebase_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElderlyProfileRepository {
  ElderlyProfileRepository._();

  static final ElderlyProfileRepository instance = ElderlyProfileRepository._();

  static const String primaryCollection = 'idoso_perfil';
  static const String legacyCollection = 'idosos';
  static const String cachedPhotoKey = 'idoso_foto_path';

  static const Set<String> allowedFields = {
    'nome',
    'idade',
    'telefone',
    'ambulancia_telefone',
    'dataNascimento',
    'endereco',
    'fotoPath',
    'supervisorId',
    'caregiverIds',
    'caregiverRoles',
    'caregiverRouting',
    'status',
    'pairingCode',
    'pairingCodeExpires',
    'createdAt',
    'updatedAt',
    'alex_voice_rate',
    'lastSeen',
    'alex_voice_pitch',
    'always_listening_enabled',
  };

  static const Set<String> clientWritableFields = {
    'nome',
    'idade',
    'telefone',
    'ambulancia_telefone',
    'dataNascimento',
    'endereco',
    'fotoPath',
    'createdAt',
    'updatedAt',
    'lastSeen',
    'alex_voice_rate',
    'alex_voice_pitch',
    'always_listening_enabled',
  };
  bool get isFirebaseAvailable => FirebaseHelper.isInitialized;

  DocumentReference<Map<String, dynamic>> primaryRef(String idosoId) =>
      FirebaseFirestore.instance.collection(primaryCollection).doc(idosoId);

  DocumentReference<Map<String, dynamic>> _legacyRef(String idosoId) =>
      FirebaseFirestore.instance.collection(legacyCollection).doc(idosoId);

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String idosoId,
  ) async {
    try {
      final primary = await primaryRef(
        idosoId,
      ).get().timeout(const Duration(seconds: 4));
      if (primary.exists) return primary;
      final legacy = await _legacyRef(
        idosoId,
      ).get().timeout(const Duration(seconds: 4));
      if (!legacy.exists) return primary;
      if (FirebaseAuth.instance.currentUser?.uid == idosoId &&
          isFirebaseAvailable) {
        try {
          await FirebaseFunctions.instance
              .httpsCallable('migrateLegacyElderlyProfile')
              .call()
              .timeout(const Duration(seconds: 8));
          final migrated = await primaryRef(
            idosoId,
          ).get().timeout(const Duration(seconds: 4));
          if (migrated.exists) return migrated;
        } catch (_) {}
      }
      return legacy;
    } catch (_) {
      return primaryRef(idosoId).get(const GetOptions(source: Source.cache));
    }
  }

  Future<Map<String, dynamic>?> getData(String idosoId) async {
    final document = await getDocument(idosoId);
    return document.data();
  }

  Future<Map<String, dynamic>> getMergedData(String idosoId) async {
    try {
      return (await getDocument(idosoId)).data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> sanitize(Map<String, dynamic> source) => {
    for (final entry in source.entries)
      if (allowedFields.contains(entry.key)) entry.key: entry.value,
  };

  Map<String, dynamic> sanitizeWritable(Map<String, dynamic> source) => {
    for (final entry in source.entries)
      if (clientWritableFields.contains(entry.key)) entry.key: entry.value,
  };

  Future<String?> getCachedPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(cachedPhotoKey);
  }
}
