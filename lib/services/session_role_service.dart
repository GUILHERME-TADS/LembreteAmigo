import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SessionRoleService {
  static const String _roleKey = 'active_user_role';
  static const String elderly = 'elderly';
  static const String supervisor = 'supervisor';
  static const String unpairedIdosoId = 'idoso_sem_vinculo';

  static String? _activeRole;

  static String? get activeRole => _activeRole;
  static bool get isSupervisor => _activeRole == supervisor;
  static bool get isElderly => _activeRole == elderly;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeRole = prefs.getString(_roleKey);
  }

  static Future<void> setElderly() => _setRole(elderly);

  static Future<void> setSupervisor() => _setRole(supervisor);

  static Future<String> getActiveIdosoId({
    String fallback = unpairedIdosoId,
  }) async {
    if (_activeRole == null) {
      await load();
    }

    final prefs = await SharedPreferences.getInstance();
    final supervisorActive = prefs.getString('selected_idoso_id');
    final elderlyActive = prefs.getString('paired_idoso_id');

    if (isElderly) {
      return elderlyActive ?? supervisorActive ?? fallback;
    }
    if (isSupervisor) {
      return supervisorActive ?? elderlyActive ?? fallback;
    }
    return supervisorActive ?? elderlyActive ?? fallback;
  }

  static Future<String?> getActiveIdosoIdOrNull() async {
    final idosoId = await getActiveIdosoId(fallback: '');
    return idosoId.isEmpty ? null : idosoId;
  }

  static Future<void> logout() async {
    _activeRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove('selected_idoso_id');
    await prefs.remove('smart_alert_notified_keys');
    
    // Se o aparelho já possuía um idoso pareado, restaura o papel de idoso automaticamente
    final pairedIdoso = prefs.getString('paired_idoso_id');
    if (pairedIdoso != null) {
      await _setRole(elderly);
    }
  }

  static Future<void> exitElderlyModeOnly() async {
    _activeRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  static Future<void> _setRole(String role) async {
    _activeRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<bool> isSupervisorConnected() async {
    if (!isSupervisor) return false;

    final idosoId = await getActiveIdosoIdOrNull();
    if (idosoId == null || idosoId == unpairedIdosoId) {
      return false;
    }

    bool useFirebase = false;
    try {
      useFirebase = Firebase.apps.isNotEmpty;
    } catch (_) {}

    if (!useFirebase) {
      return idosoId != unpairedIdosoId;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      return data['supervisorId'] == currentUser.uid &&
          data['status'] == 'active';
    } catch (e) {
      debugPrint('Erro ao verificar conexao do supervisor no Firestore: $e');
      return false;
    }
  }
}

