import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';

class AchievementService {
  AchievementService._();
  static final AchievementService instance = AchievementService._();

  final ValueNotifier<List<Achievement>> achievements =
      ValueNotifier([]);
  final ValueNotifier<Achievement?> lastUnlocked =
      ValueNotifier(null);

  bool _initialized = false;
  StreamSubscription? _subscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final idosoId = await _getIdosoId();
    if (idosoId == null) return;

    final saved = await _loadFromCache();
    if (saved.isNotEmpty) {
      achievements.value = saved;
    }

    _subscription = FirebaseFirestore.instance
        .collection('achievements')
        .doc(idosoId)
        .collection('medalhas')
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs
          .map((d) => Achievement.fromFirestore(d))
          .toList();

      final merged = Achievement.allDefinitions.map((def) {
        final existing =
            list.where((a) => a.id == def.id).firstOrNull;
        if (existing != null && existing.desbloqueado) return existing;
        final cached = achievements.value
            .where((a) => a.id == def.id)
            .firstOrNull;
        if (cached != null && cached.desbloqueado) return cached;
        return def.copyWith(
          progresso: existing?.progresso ?? cached?.progresso ?? 0,
        );
      }).toList();

      achievements.value = merged;
      _saveToCache(merged);
    });
  }

  void dispose() {
    _subscription?.cancel();
    achievements.dispose();
    lastUnlocked.dispose();
  }

  Future<void> checkAndUnlock({
    int? streakDays,
    int? totalCompletions,
    int? onTimeDays,
    bool? familyCompleted,
  }) async {
    final idosoId = await _getIdosoId();
    if (idosoId == null) return;

    final current = achievements.value;

    for (final ach in current) {
      if (ach.desbloqueado) continue;

      bool shouldUnlock = false;

      switch (ach.id) {
        case 'primeiro_passo':
          shouldUnlock = (totalCompletions ?? 0) >= 1;
          break;
        case 'semana_de_ouro':
          shouldUnlock = (streakDays ?? 0) >= 7;
          break;
        case 'mes_dedicado':
          shouldUnlock = (streakDays ?? 0) >= 30;
          break;
        case 'foco_total':
          shouldUnlock = (onTimeDays ?? 0) >= 7;
          break;
        case 'heroi_da_familia':
          shouldUnlock = familyCompleted ?? false;
          break;
        case 'mestre_remedios':
          shouldUnlock = (totalCompletions ?? 0) >= 100;
          break;
      }

      if (shouldUnlock) {
        await _unlock(ach, idosoId);
      }
    }
  }

  Future<void> updateProgress({
    int? streakDays,
    int? totalCompletions,
    int? onTimeDays,
  }) async {
    final idosoId = await _getIdosoId();
    if (idosoId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final ref = FirebaseFirestore.instance
        .collection('achievements')
        .doc(idosoId)
        .collection('medalhas');

    final updated = achievements.value.map((ach) {
      if (ach.desbloqueado) return ach;

      double newProgress = ach.progresso;

      switch (ach.id) {
        case 'semana_de_ouro':
          newProgress = (streakDays ?? 0).toDouble();
          break;
        case 'mes_dedicado':
          newProgress = (streakDays ?? 0).toDouble();
          break;
        case 'foco_total':
          newProgress = (onTimeDays ?? 0).toDouble();
          break;
        case 'mestre_remedios':
          newProgress = (totalCompletions ?? 0).toDouble();
          break;
      }

      if (newProgress != ach.progresso) {
        batch.set(
          ref.doc(ach.id),
          {'progresso': newProgress, 'id': ach.id},
          SetOptions(merge: true),
        );
      }

      return ach.copyWith(progresso: newProgress);
    }).toList();

    await batch.commit();
    achievements.value = updated;
    _saveToCache(updated);
  }

  Future<void> _unlock(
      Achievement ach, String idosoId) async {
    final unlocked = ach.copyWith(
      dataDesbloqueio: DateTime.now(),
      progresso: ach.progressoMaximo,
    );

    await FirebaseFirestore.instance
        .collection('achievements')
        .doc(idosoId)
        .collection('medalhas')
        .doc(ach.id)
        .set(unlocked.toMap());

    lastUnlocked.value = unlocked;

    final updated =
        achievements.value.map((a) {
      if (a.id == ach.id) return unlocked;
      return a;
    }).toList();
    achievements.value = updated;
    _saveToCache(updated);

    try {
      await TTSService.instance.falar(
        'Parabéns! Você ganhou a medalha ${ach.titulo}!',
      );
    } catch (_) {}
  }

  Future<String?> _getIdosoId() async {
    try {
      return await SessionRoleService.getActiveIdosoId();
    } catch (_) {
      return null;
    }
  }

  Future<List<Achievement>> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('achievement_cache_count') ?? 0;
    final list = <Achievement>[];
    for (int i = 0; i < count; i++) {
      final json = prefs.getString('achievement_cache_$i');
      if (json != null) {
        try {
          final map =
              Map<String, dynamic>.from(
                  const <String, dynamic>{});
          json.split(',').forEach((pair) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              map[parts[0]] = parts[1];
            }
          });
          list.add(Achievement.fromMap(map));
        } catch (_) {}
      }
    }
    return list;
  }

  Future<void> _saveToCache(List<Achievement> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('achievement_cache_count', list.length);
    for (int i = 0; i < list.length; i++) {
      await prefs.setString(
        'achievement_cache_$i',
        list[i].toMap().entries.map((e) => '${e.key}:${e.value}').join(','),
      );
    }
  }
}
