import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/device_barrier.dart';
import '../models/device_diagnostics.dart';
import 'offline_sync_service.dart';
import 'session_role_service.dart';
import '../utils/firebase_helper.dart';
import 'volume_service.dart';
import 'tts_service.dart';

class DeviceBarrierService {
  DeviceBarrierService._();
  static final DeviceBarrierService instance = DeviceBarrierService._();

  static const _lastElderlyHeartbeatKey = 'device_last_elderly_heartbeat_at';
  static const _lastSnapshotKey = 'device_barrier_snapshot';
  static const _publishTimeout = Duration(seconds: 6);
  static const _staleRemoteSnapshotAfter = Duration(minutes: 30);
  static const _criticalRemoteSnapshotAfter = Duration(hours: 12);

  final ValueNotifier<List<DeviceBarrier>> notifier = ValueNotifier([]);
  bool _refreshing = false;

  List<DeviceBarrier> get barriers => List.unmodifiable(notifier.value);

  bool get _useFirebase => FirebaseHelper.isInitialized;

  Future<void> markElderlyActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastElderlyHeartbeatKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> refresh({
    bool markElderlyActive = false,
    bool publish = false,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (markElderlyActive) {
        await this.markElderlyActive();
      }

      final now = DateTime.now();
      final barriers = <DeviceBarrier>[];

      // Leitura do nível e estado da bateria
      int? batteryLevel;
      String? batteryState;
      try {
        final battery = Battery();
        batteryLevel = await battery.batteryLevel;
        final state = await battery.batteryState;
        batteryState = state.name;

        if (batteryLevel <= 15 && batteryState != 'charging') {
          barriers.add(
            DeviceBarrier(
              type: DeviceBarrierType.lowBattery,
              severity: batteryLevel <= 8
                  ? DeviceBarrierSeverity.critical
                  : DeviceBarrierSeverity.warning,
              title: 'Bateria Fraca',
              message:
                  'A bateria do celular esta em $batteryLevel%. Coloque no carregador para nao perder lembretes.',
              detectedAt: now,
              priority: batteryLevel <= 8 ? 100 : 85,
              value: batteryLevel,
            ),
          );

          if (SessionRoleService.isElderly) {
            final prefs = await SharedPreferences.getInstance();
            final lastSpoken = prefs.getInt('last_low_battery_spoken_ms') ?? 0;
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            if (nowMs - lastSpoken > 15 * 60 * 1000) {
              await prefs.setInt('last_low_battery_spoken_ms', nowMs);
              TTSService.instance.falar(
                'Atenção: a bateria do seu celular está acabando, em $batteryLevel por cento. Por favor, coloque o celular no carregador.',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao ler bateria: $e');
      }

      final volume = await VolumeService.getVolumePercentage();
      if (VolumeService.isLow(volume)) {
        barriers.add(
          DeviceBarrier(
            type: DeviceBarrierType.lowVolume,
            severity: volume <= 15
                ? DeviceBarrierSeverity.critical
                : DeviceBarrierSeverity.warning,
            title: 'Som baixo',
            message:
                'O celular esta com volume em $volume%. O idoso pode nao ouvir os lembretes.',
            detectedAt: now,
            priority: volume <= 15 ? 100 : 80,
            value: volume,
          ),
        );
      }

      final online = await _hasInternet();
      if (!online) {
        barriers.add(
          DeviceBarrier(
            type: DeviceBarrierType.offline,
            severity: DeviceBarrierSeverity.warning,
            title: 'Sem internet',
            message:
                'Confirmacoes e recados podem demorar para chegar ao cuidador.',
            detectedAt: now,
            priority: 70,
          ),
        );
      }

      final pendingWrites = await OfflineSyncService.instance.loadQueue();
      if (pendingWrites.isNotEmpty) {
        barriers.add(
          DeviceBarrier(
            type: DeviceBarrierType.pendingSync,
            severity: pendingWrites.length >= 5
                ? DeviceBarrierSeverity.warning
                : DeviceBarrierSeverity.info,
            title: 'Sincronizacao pendente',
            message:
                '${pendingWrites.length} acao${pendingWrites.length == 1 ? '' : 'es'} ainda nao chegaram na nuvem. O app vai tentar enviar automaticamente.',
            detectedAt: now,
            priority: pendingWrites.length >= 5 ? 65 : 35,
            value: pendingWrites.length,
          ),
        );
      }

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
          if (!isIgnoring) {
            barriers.add(
              DeviceBarrier(
                type: DeviceBarrierType.batteryOptimization,
                severity: DeviceBarrierSeverity.warning,
                title: 'Otimização de Bateria Ativa',
                message:
                    'O Android pode suspender os alarmes com a tela apagada. Toque para autorizar o funcionamento contínuo.',
                detectedAt: now,
                priority: 88,
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao verificar otimizacao de bateria: $e');
        }
      }

      final lastHeartbeat = await _lastElderlyHeartbeat();
      if (lastHeartbeat != null) {
        final inactiveFor = now.difference(lastHeartbeat);
        if (inactiveFor.inHours >= 4) {
          barriers.add(
            DeviceBarrier(
              type: DeviceBarrierType.inactiveApp,
              severity: inactiveFor.inHours >= 12
                  ? DeviceBarrierSeverity.critical
                  : DeviceBarrierSeverity.warning,
              title: 'App sem uso recente',
              message:
                  'O modo idoso nao envia sinal ha ${_formatDuration(inactiveFor)}. Verifique se o celular esta ligado.',
              detectedAt: now,
              priority: inactiveFor.inHours >= 12 ? 95 : 60,
              value: inactiveFor.inHours,
            ),
          );
        }
      }

      barriers.sort((a, b) => b.priority.compareTo(a.priority));
      notifier.value = barriers;
      await _saveSnapshot(
        barriers,
        batteryLevel: batteryLevel,
        batteryState: batteryState,
      );
      if (publish && online) {
        await _publishSnapshot(
          barriers,
          updatedAt: now,
          batteryLevel: batteryLevel,
          batteryState: batteryState,
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<DateTime?> _lastElderlyHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastElderlyHeartbeatKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> _hasInternet() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveSnapshot(
    List<DeviceBarrier> barriers, {
    int? batteryLevel,
    String? batteryState,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadLocalDiagnostics();
    final diagnostics = DeviceDiagnostics(
      barriers: barriers,
      batteryLevel: batteryLevel,
      batteryState: batteryState,
      updatedAt: DateTime.now(),
      lastAlarmTestAt: previous.lastAlarmTestAt,
      lastAlarmTestSuccessful: previous.lastAlarmTestSuccessful,
    );
    await prefs.setString(_lastSnapshotKey, jsonEncode(diagnostics.toJson()));
  }

  Future<List<DeviceBarrier>> loadLocalSnapshot() async {
    final diagnostics = await loadLocalDiagnostics();
    return diagnostics.barriers;
  }

  Future<DeviceDiagnostics> loadLocalDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSnapshotKey);
    if (raw == null || raw.isEmpty) {
      return const DeviceDiagnostics(barriers: []);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DeviceDiagnostics.fromJson(Map<String, dynamic>.from(decoded));
      } else if (decoded is List) {
        final list = decoded;
        final barriers = list
            .whereType<Map>()
            .map(
              (item) => DeviceBarrier.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        return DeviceDiagnostics(barriers: barriers);
      }
      return const DeviceDiagnostics(barriers: []);
    } catch (_) {
      return const DeviceDiagnostics(barriers: []);
    }
  }

  Stream<List<DeviceBarrier>> watchRemoteBarriers(String idosoId) {
    return watchRemoteDiagnostics(idosoId).map((d) => d.barriers);
  }

  Stream<DeviceDiagnostics> watchRemoteDiagnostics(String idosoId) {
    if (!_useFirebase) {
      return Stream.fromFuture(loadLocalDiagnostics());
    }

    return FirebaseFirestore.instance
        .collection('device_diagnostics')
        .doc(idosoId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (SessionRoleService.isSupervisor) {
            final connected = await SessionRoleService.isSupervisorConnected();
            if (!connected) {
              return DeviceDiagnostics(
                barriers: const [],
                batteryLevel: null,
                batteryState: null,
                updatedAt: DateTime.now(),
              );
            }
          }
          final now = DateTime.now();
          if (!snapshot.exists || snapshot.data() == null) {
            return DeviceDiagnostics(
              barriers: [
                DeviceBarrier(
                  type: DeviceBarrierType.inactiveApp,
                  severity: DeviceBarrierSeverity.info,
                  title: 'Radar aguardando dados',
                  message:
                      'Abra o aplicativo no celular do idoso para enviar o primeiro diagnostico.',
                  detectedAt: now,
                  priority: 20,
                ),
              ],
              updatedAt: now,
            );
          }

          final data = Map<String, dynamic>.from(snapshot.data()!);
          final updatedAt = DateTime.tryParse(
            data['updatedAt'] as String? ?? '',
          );
          final rawBarriers = data['barriers'] is List
              ? data['barriers'] as List
              : const [];
          final barriers = rawBarriers
              .whereType<Map>()
              .map(
                (item) =>
                    DeviceBarrier.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();

          if (updatedAt == null) {
            barriers.add(_buildStaleRemoteBarrier(now, null));
          } else {
            final age = now.difference(updatedAt);
            if (age >= _staleRemoteSnapshotAfter) {
              barriers.add(_buildStaleRemoteBarrier(now, age));
            }
          }

          barriers.sort((a, b) => b.priority.compareTo(a.priority));

          final batteryLevel = (data['batteryLevel'] as num?)?.toInt();
          final batteryState = data['batteryState'] as String?;

          return DeviceDiagnostics(
            barriers: barriers,
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            updatedAt: updatedAt,
            lastAlarmTestAt: DateTime.tryParse(
              data['lastAlarmTestAt'] as String? ?? '',
            ),
            lastAlarmTestSuccessful: data['lastAlarmTestSuccessful'] as bool?,
          );
        });
  }

  DeviceBarrier _buildStaleRemoteBarrier(DateTime now, Duration? age) {
    final isCritical = age == null || age >= _criticalRemoteSnapshotAfter;
    final ageText = age == null
        ? 'ha algum tempo'
        : 'ha ${_formatDuration(age)}';
    return DeviceBarrier(
      type: DeviceBarrierType.inactiveApp,
      severity: isCritical
          ? DeviceBarrierSeverity.critical
          : DeviceBarrierSeverity.warning,
      title: 'Radar sem atualizacao',
      message:
          'O diagnostico do celular do idoso nao atualiza $ageText. Verifique se o app esta aberto e com internet.',
      detectedAt: now,
      priority: isCritical ? 95 : 60,
      value: age?.inMinutes,
    );
  }

  Future<void> _publishSnapshot(
    List<DeviceBarrier> barriers, {
    required DateTime updatedAt,
    int? batteryLevel,
    String? batteryState,
  }) async {
    if (!_useFirebase) return;
    if (!SessionRoleService.isElderly) return;
    if (!await SessionRoleService.canSyncElderlyPrivateData()) return;
    try {
      final user = await SessionRoleService.ensureElderlyAuthSession();
      final idosoId = await SessionRoleService.getActiveIdosoId();
      if (user == null || user.uid != idosoId) return;
      await FirebaseFirestore.instance
          .collection('device_diagnostics')
          .doc(idosoId)
          .set({
            'updatedAt': updatedAt.toIso8601String(),
            'barriers': barriers.map((barrier) => barrier.toJson()).toList(),
            'criticalCount': barriers
                .where((b) => b.severity == DeviceBarrierSeverity.critical)
                .length,
            'warningCount': barriers
                .where((b) => b.severity == DeviceBarrierSeverity.warning)
                .length,
            'batteryLevel': batteryLevel,
            'batteryState': batteryState,
          }, SetOptions(merge: true))
          .timeout(_publishTimeout);
    } catch (e) {
      debugPrint('Erro ao publicar diagnostico do aparelho: $e');
    }
  }

  Future<void> recordAlarmTest({required bool successful}) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadLocalDiagnostics();
    final testedAt = DateTime.now();
    final diagnostics = DeviceDiagnostics(
      barriers: previous.barriers,
      batteryLevel: previous.batteryLevel,
      batteryState: previous.batteryState,
      updatedAt: previous.updatedAt,
      lastAlarmTestAt: testedAt,
      lastAlarmTestSuccessful: successful,
    );
    await prefs.setString(_lastSnapshotKey, jsonEncode(diagnostics.toJson()));
    if (!_useFirebase || !SessionRoleService.isElderly) return;
    if (!await SessionRoleService.canSyncElderlyPrivateData()) return;
    final user = await SessionRoleService.ensureElderlyAuthSession();
    final idosoId = await SessionRoleService.getActiveIdosoId();
    if (user == null || user.uid != idosoId) return;
    await FirebaseFirestore.instance
        .collection('device_diagnostics')
        .doc(idosoId)
        .set({
          'lastAlarmTestAt': testedAt.toIso8601String(),
          'lastAlarmTestSuccessful': successful,
          'updatedAt': testedAt.toIso8601String(),
        }, SetOptions(merge: true))
        .timeout(_publishTimeout);
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return '${duration.inDays} dia${duration.inDays == 1 ? '' : 's'}';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours} hora${duration.inHours == 1 ? '' : 's'}';
    }
    return '${duration.inMinutes} minuto${duration.inMinutes == 1 ? '' : 's'}';
  }
}
