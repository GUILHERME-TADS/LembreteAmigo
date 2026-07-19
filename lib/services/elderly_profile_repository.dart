import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElderlyProfileRepository {
  ElderlyProfileRepository._();

  static final ElderlyProfileRepository instance =
      ElderlyProfileRepository._();

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
    'status',
    'pairingCode',
    'pairingCodeExpires',
    'createdAt',
    'updatedAt',
  };

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  DocumentReference<Map<String, dynamic>> primaryRef(String idosoId) =>
      FirebaseFirestore.instance.collection(primaryCollection).doc(idosoId);

  DocumentReference<Map<String, dynamic>> legacyRef(String idosoId) =>
      FirebaseFirestore.instance.collection(legacyCollection).doc(idosoId);

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String idosoId,
  ) async {
    final primary = await primaryRef(idosoId).get();
    if (primary.exists) return primary;
    return legacyRef(idosoId).get();
  }

  Future<Map<String, dynamic>?> getData(String idosoId) async {
    final document = await getDocument(idosoId);
    return document.data();
  }

  Future<Map<String, dynamic>> getMergedData(String idosoId) async {
    final documents = await Future.wait([
      legacyRef(idosoId).get(),
      primaryRef(idosoId).get(),
    ]);
    return <String, dynamic>{
      ...?documents[0].data(),
      ...?documents[1].data(),
    };
  }

  Map<String, dynamic> sanitize(Map<String, dynamic> source) => {
        for (final entry in source.entries)
          if (allowedFields.contains(entry.key)) entry.key: entry.value,
      };

  Future<String?> getCachedPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(cachedPhotoKey);
  }
}
