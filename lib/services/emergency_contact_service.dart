import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_role_service.dart';

class EmergencyContactService {
  EmergencyContactService._();

  static final EmergencyContactService instance = EmergencyContactService._();

  static const _ambulanceKeys = [
    'ambulance_phone',
    'ambulancia_phone',
    'ambulancia_telefone',
    'telefone_ambulancia',
    'emergency_ambulance_phone',
    'numero_ambulancia',
  ];

  Future<String?> getAmbulancePhone() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in _ambulanceKeys) {
      final value = _cleanPhone(prefs.getString(key));
      if (value != null) return value;
    }

    final localProfile = prefs.getString('idoso_perfil');
    final localPhone = _phoneFromJson(localProfile);
    if (localPhone != null) return localPhone;

    if (Firebase.apps.isEmpty) return null;

    final idosoId = await SessionRoleService.getActiveIdosoId();
    if (idosoId.isEmpty || idosoId == SessionRoleService.unpairedIdosoId) {
      return null;
    }

    final profilePhone = await _phoneFromFirestore('idoso_perfil', idosoId);
    if (profilePhone != null) return profilePhone;

    return _phoneFromFirestore('idosos', idosoId);
  }

  String? _phoneFromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) return null;
      return _phoneFromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _phoneFromFirestore(String collection, String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(id).get();
      final data = doc.data();
      if (data == null) return null;
      return _phoneFromMap(data);
    } catch (_) {
      return null;
    }
  }

  String? _phoneFromMap(Map<String, dynamic> data) {
    for (final key in _ambulanceKeys) {
      final value = _cleanPhone(data[key]?.toString());
      if (value != null) return value;
    }
    return null;
  }

  String? _cleanPhone(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (cleaned == null || cleaned.length < 3) return null;
    return cleaned;
  }
}
