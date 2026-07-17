import 'dart:convert';

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
  static bool _lastVerificationFailedByError = false;

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
      return elderlyActive ?? fallback;
    }
    if (isSupervisor) {
      return supervisorActive ?? fallback;
    }
    return fallback;
  }

  static Future<User?> ensureElderlyAuthSession() async {
    if (!isElderly) return FirebaseAuth.instance.currentUser;
    if (Firebase.apps.isEmpty) return FirebaseAuth.instance.currentUser;

    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;

    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('paired_idoso_id', user.uid);
    }
    return user;
  }

  static Future<String?> getVerifiedActiveIdosoId() async {
    _lastVerificationFailedByError = false;
    final idosoId = await getActiveIdosoIdOrNull();
    if (idosoId == null ||
        idosoId == unpairedIdosoId ||
        idosoId == 'idoso_simulado') {
      return idosoId;
    }

    if (idosoId == 'idoso_autonomo') return idosoId;

    if (Firebase.apps.isEmpty) return idosoId;

    if (isElderly) {
      final user = await ensureElderlyAuthSession();
      return user != null && user.uid == idosoId ? idosoId : null;
    }

    if (isSupervisor) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get()
            .timeout(const Duration(seconds: 4));
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        final linked = data['supervisorId'] == currentUser.uid &&
            data['status'] == 'active';
        return linked ? idosoId : null;
      } catch (e) {
        _lastVerificationFailedByError = true;
        debugPrint('Erro ao validar vinculo ativo: $e');
        return null;
      }
    }

    return null;
  }

  static Future<bool> canUseActiveIdoso({bool allowOfflineCache = false}) async {
    final verified = await getVerifiedActiveIdosoId();
    if (verified != null &&
        verified != unpairedIdosoId &&
        verified != 'idoso_simulado') {
      return true;
    }
    if (!allowOfflineCache) return false;
    if (Firebase.apps.isNotEmpty && !_lastVerificationFailedByError) {
      return false;
    }

    final cached = await getActiveIdosoIdOrNull();
    return cached != null && cached != unpairedIdosoId;
  }

  static Future<String?> getActiveIdosoIdOrNull() async {
    final idosoId = await getActiveIdosoId(fallback: '');
    return idosoId.isEmpty ? null : idosoId;
  }

  static Future<bool> isElderlyConnectedToSupervisor() async {
    final prefs = await SharedPreferences.getInstance();
    final idosoId = prefs.getString('paired_idoso_id');
    if (idosoId == null ||
        idosoId.isEmpty ||
        idosoId == unpairedIdosoId ||
        idosoId == 'idoso_autonomo') {
      return false;
    }

    final jsonStr = prefs.getString('idoso_perfil');
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'active' && data['supervisorId'] != null) {
          await prefs.setBool('elderly_autonomous_mode', false);
          return true;
        }
        if (status != null) return false;
      } catch (_) {}
    }

    return !(prefs.getBool('elderly_autonomous_mode') ?? false);
  }

  static Future<void> logout() async {
    _activeRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove('selected_idoso_id');
    await prefs.remove('smart_alert_notified_keys');
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

    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Wait up to 1500ms for Firebase Auth to finish initialization (prevent startup race condition)
      try {
        await Future.any([
          FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null),
          Future.delayed(const Duration(milliseconds: 1500)),
        ]);
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    if (currentUser == null) {
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .get()
          .timeout(const Duration(seconds: 3));
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      final isConnected = data['supervisorId'] == currentUser.uid &&
          data['status'] == 'active';
      return isConnected;
    } catch (e) {
      debugPrint('Erro ao verificar conexao do supervisor no Firestore: $e');
      return false;
    }
  }
}

