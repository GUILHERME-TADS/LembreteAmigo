import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'alex_voice_profile.dart';
import 'tts_service.dart';
import 'always_listening_service.dart';
import 'secure_cache_service.dart';
import '../utils/firebase_helper.dart';

class SessionRoleService {
  static const String _roleKey = 'active_user_role';
  static const String elderly = 'elderly';
  static const String supervisor = 'supervisor';
  static const String unpairedIdosoId = 'idoso_local';
  static const String autonomousIdosoId = 'idoso_local';

  static String? _activeRole;
  static bool _lastVerificationFailedByError = false;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _elderlyProfileSubscription;
  static String? _watchedElderlyId;
  static final ValueNotifier<bool?> elderlyConnectionNotifier =
      ValueNotifier<bool?>(null);

  static String? get activeRole => _activeRole;
  static bool get isSupervisor => _activeRole == supervisor;
  static bool get isElderly => _activeRole == elderly;
  static bool isLocalOnlyIdosoId(String? idosoId) =>
      idosoId == null ||
      idosoId.isEmpty ||
      idosoId == 'idoso_local' ||
      idosoId == 'idoso_simulado';

  static List<String> caregiverIdsFromProfile(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final ids = <String>{
      ...((data['caregiverIds'] as List?) ?? const [])
          .whereType<String>()
          .where((id) => id.isNotEmpty),
      if (data['supervisorId'] is String &&
          (data['supervisorId'] as String).isNotEmpty)
        data['supervisorId'] as String,
    };
    return ids.take(8).toList();
  }

  static bool isCaregiverInProfile(
    Map<String, dynamic>? data,
    String caregiverId,
  ) =>
      data?['status'] == 'active' &&
      caregiverIdsFromProfile(data).contains(caregiverId);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeRole = prefs.getString(_roleKey);
  }

  static Future<void> setElderly() => _setRole(elderly);

  static Future<void> setSupervisor() => _setRole(supervisor);

  static Future<bool> restoreSupervisorIdosoLink() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || Firebase.apps.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final cachedIdosoId = prefs.getString('selected_idoso_id');

    try {
      if (!isLocalOnlyIdosoId(cachedIdosoId)) {
        final cachedDoc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(cachedIdosoId)
            .get()
            .timeout(const Duration(seconds: 4));
        final cachedData = cachedDoc.data();
        if (cachedDoc.exists &&
            isCaregiverInProfile(cachedData, currentUser.uid)) {
          return true;
        }
        await prefs.remove('selected_idoso_id');
      }

      var snapshot = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .where('supervisorId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'active')
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .where('caregiverIds', arrayContains: currentUser.uid)
            .where('status', isEqualTo: 'active')
            .get()
            .timeout(const Duration(seconds: 5));
      }

      if (snapshot.docs.isEmpty) return false;

      final linkedIds = snapshot.docs.map((doc) => doc.id).toList()..sort();
      await prefs.setString('selected_idoso_id', linkedIds.first);
      return true;
    } catch (e) {
      debugPrint('Erro ao restaurar vinculo do cuidador: $e');
      return false;
    }
  }

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
      if (FirebaseHelper.isDemoRecording && elderlyActive != null) {
        return elderlyActive;
      }
      final authenticatedId = Firebase.apps.isNotEmpty
          ? FirebaseAuth.instance.currentUser?.uid
          : null;
      if (authenticatedId != null) {
        if (elderlyActive != authenticatedId) {
          await prefs.setString('paired_idoso_id', authenticatedId);
        }
        return authenticatedId;
      }
      return fallback;
    }
    if (isSupervisor) {
      return supervisorActive ?? fallback;
    }
    return fallback;
  }

  static Future<User?> ensureElderlyAuthSession() async {
    if (!isElderly) return FirebaseAuth.instance.currentUser;
    if (Firebase.apps.isEmpty) return FirebaseAuth.instance.currentUser;
    return FirebaseAuth.instance.currentUser;
  }

  static Future<String> ensureStableElderlyId() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    if (user == null) {
      throw StateError('Entre com Google para acessar o modo idoso.');
    }
    await prefs.setString('paired_idoso_id', user.uid);
    return user.uid;
  }

  static Future<String?> getVerifiedActiveIdosoId() async {
    _lastVerificationFailedByError = false;
    final idosoId = await getActiveIdosoIdOrNull();
    if (FirebaseHelper.isDemoRecording && idosoId == 'idoso_simulado') {
      return idosoId;
    }
    if (isLocalOnlyIdosoId(idosoId)) {
      return idosoId;
    }

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
        final linked = isCaregiverInProfile(data, currentUser.uid);
        return linked ? idosoId : null;
      } catch (e) {
        _lastVerificationFailedByError = true;
        debugPrint('Erro ao validar vinculo ativo: $e');
        return null;
      }
    }

    return null;
  }

  static Future<bool> canUseActiveIdoso({
    bool allowOfflineCache = false,
  }) async {
    final verified = await getVerifiedActiveIdosoId();
    if (FirebaseHelper.isDemoRecording && verified == 'idoso_simulado') {
      return true;
    }
    if (verified != null && !isLocalOnlyIdosoId(verified)) {
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
    if (FirebaseHelper.isDemoRecording && idosoId == 'idoso_simulado') {
      return true;
    }
    if (isLocalOnlyIdosoId(idosoId)) {
      return false;
    }

    final jsonStr = await SecureCacheService.instance.readElderlyProfile();
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'active' && caregiverIdsFromProfile(data).isNotEmpty) {
          await prefs.setBool('elderly_autonomous_mode', false);
          return true;
        }
        if (status != null) return false;
      } catch (_) {}
    }

    return !(prefs.getBool('elderly_autonomous_mode') ?? false);
  }

  static Future<bool> canSyncElderlyPrivateData() async {
    final verified = await getVerifiedActiveIdosoId();
    return verified != null && !isLocalOnlyIdosoId(verified);
  }

  static Future<void> watchElderlyConnection() async {
    if (FirebaseHelper.isDemoRecording) {
      elderlyConnectionNotifier.value = true;
      return;
    }
    if (!isElderly || Firebase.apps.isEmpty) return;
    if (!await canSyncElderlyPrivateData()) {
      await stopWatchingElderlyConnection();
      elderlyConnectionNotifier.value = false;
      return;
    }
    final idosoId = await getActiveIdosoIdOrNull();
    if (isLocalOnlyIdosoId(idosoId)) {
      elderlyConnectionNotifier.value = false;
      return;
    }
    if (_watchedElderlyId == idosoId && _elderlyProfileSubscription != null) {
      return;
    }

    await _elderlyProfileSubscription?.cancel();
    _watchedElderlyId = idosoId;
    _elderlyProfileSubscription = FirebaseFirestore.instance
        .collection('idoso_perfil')
        .doc(idosoId)
        .snapshots()
        .listen(
          (snapshot) async {
            final data = snapshot.data();
            final connected =
                snapshot.exists &&
                data?['status'] == 'active' &&
                caregiverIdsFromProfile(data).isNotEmpty;
            final prefs = await SharedPreferences.getInstance();
            final cachedJson = await SecureCacheService.instance
                .readElderlyProfile();
            final cachedProfile = <String, dynamic>{};
            if (cachedJson != null) {
              try {
                cachedProfile.addAll(
                  Map<String, dynamic>.from(
                    jsonDecode(cachedJson) as Map<String, dynamic>,
                  ),
                );
              } catch (error) {
                debugPrint('Perfil local invalido substituido: $error');
              }
            }
            if (data != null) {
              cachedProfile.addAll(data);
            }
            if (!connected) {
              cachedProfile['supervisorId'] = null;
              cachedProfile['caregiverIds'] = <String>[];
              cachedProfile['caregiverRoles'] = <String, String>{};
            }
            cachedProfile['status'] = connected ? 'active' : 'pending';
            await SecureCacheService.instance.writeElderlyProfile(
              jsonEncode(cachedProfile),
            );
            await prefs.setBool('elderly_autonomous_mode', !connected);
            if (data != null) {
              await syncVoiceAndListeningSettings(data);
            }
            elderlyConnectionNotifier.value = connected;
            if (!connected) {
              await stopWatchingElderlyConnection();
              elderlyConnectionNotifier.value = false;
            }
          },
          onError: (Object error) {
            if (error is! FirebaseException ||
                error.code != 'permission-denied') {
              debugPrint('Não foi possível atualizar o estado do vínculo.');
            }
            unawaited(stopWatchingElderlyConnection());
            elderlyConnectionNotifier.value = false;
          },
        );
  }

  static Future<void> stopWatchingElderlyConnection() async {
    await _elderlyProfileSubscription?.cancel();
    _elderlyProfileSubscription = null;
    _watchedElderlyId = null;
    elderlyConnectionNotifier.value = null;
  }

  static Future<void> logout() async {
    await stopWatchingElderlyConnection();
    _activeRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove('selected_idoso_id');
    await prefs.remove('smart_alert_notified_keys');
  }

  static Future<void> exitElderlyModeOnly() async {
    await stopWatchingElderlyConnection();
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
    if (FirebaseHelper.isDemoRecording && idosoId == 'idoso_simulado') {
      return true;
    }
    if (isLocalOnlyIdosoId(idosoId)) {
      return false;
    }

    bool useFirebase = false;
    try {
      useFirebase = Firebase.apps.isNotEmpty;
    } catch (_) {}

    if (!useFirebase) {
      return !isLocalOnlyIdosoId(idosoId);
    }

    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Wait up to 1500ms for Firebase Auth to finish initialization (prevent startup race condition)
      try {
        await Future.any([
          FirebaseAuth.instance.authStateChanges().firstWhere(
            (user) => user != null,
          ),
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

      return isCaregiverInProfile(data, currentUser.uid);
    } catch (e) {
      debugPrint('Erro ao verificar conexao do supervisor no Firestore: $e');
      return false;
    }
  }

  static Future<void> syncVoiceAndListeningSettings(
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rate = data['alex_voice_rate'] as num?;
    final pitch = data['alex_voice_pitch'] as num?;
    final listening = data['always_listening_enabled'] as bool?;

    bool voiceUpdated = false;
    if (rate != null) {
      final currentRate = prefs.getDouble('alex_voice_rate');
      if (currentRate != rate.toDouble()) {
        await prefs.setDouble('alex_voice_rate', rate.toDouble());
        voiceUpdated = true;
      }
    }
    if (pitch != null) {
      final currentPitch = prefs.getDouble('alex_voice_pitch');
      if (currentPitch != pitch.toDouble()) {
        await prefs.setDouble('alex_voice_pitch', pitch.toDouble());
        voiceUpdated = true;
      }
    }
    if (voiceUpdated) {
      final newProfile = await AlexVoiceProfile.load();
      await TTSService.instance.initFromProfile(newProfile);
    }
    if (listening != null) {
      final currentListening =
          prefs.getBool('always_listening_enabled') ?? false;
      if (currentListening != listening) {
        unawaited(AlwaysListeningService.instance.setEnabled(listening));
      }
    }
  }
}
