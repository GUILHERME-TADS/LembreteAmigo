import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/device_barrier.dart';
import '../services/device_barrier_service.dart';
import '../services/tts_service.dart';
import '../services/volume_service.dart';
import '../theme/app_theme.dart';

class DeviceBarrierBanner extends StatefulWidget {
  const DeviceBarrierBanner({super.key});

  @override
  State<DeviceBarrierBanner> createState() => _DeviceBarrierBannerState();
}

class _DeviceBarrierBannerState extends State<DeviceBarrierBanner>
    with WidgetsBindingObserver {
  List<DeviceBarrier> _barriers = const [];
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _barriers = DeviceBarrierService.instance.barriers
        .where((barrier) => barrier.type != DeviceBarrierType.lowVolume)
        .toList();
    DeviceBarrierService.instance.notifier.addListener(_onBarriersChanged);
    _refresh(markElderlyActive: true, publish: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(markElderlyActive: true, publish: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeviceBarrierService.instance.notifier.removeListener(_onBarriersChanged);
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _onBarriersChanged() {
    if (!mounted) return;
    setState(() {
      _barriers = DeviceBarrierService.instance.barriers
          .where((barrier) => barrier.type != DeviceBarrierType.lowVolume)
          .toList();
    });
  }

  Future<void> _refresh({
    bool markElderlyActive = false,
    bool publish = false,
  }) async {
    await DeviceBarrierService.instance.refresh(
      markElderlyActive: markElderlyActive,
      publish: publish,
    );
  }

  Future<void> _runPrimaryAction(DeviceBarrier barrier) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      switch (barrier.type) {
        case DeviceBarrierType.lowVolume:
          await VolumeService.setSafeVolume();
          await TTSService.instance.falar(
            'Pronto. Ajustei o volume. Agora voce deve conseguir ouvir os lembretes.',
            caller: this,
          );
          break;
        case DeviceBarrierType.pendingSync:
        case DeviceBarrierType.offline:
          break;
        case DeviceBarrierType.locationUnavailable:
          await Geolocator.openLocationSettings();
          break;
        case DeviceBarrierType.inactiveApp:
          await TTSService.instance.falar(
            'Tudo certo. O aplicativo esta aberto agora.',
            caller: this,
          );
          break;
      }
      await _refresh(markElderlyActive: true, publish: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _hearExplanation(DeviceBarrier barrier) async {
    await TTSService.instance.falar(
      '${barrier.title}. ${barrier.message}',
      caller: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_barriers.isNotEmpty) {
      final barrier = _barriers.first;
      _colorsFor(barrier.severity);
      _hasPrimaryAction(barrier.type);
      _iconFor(barrier.type);
      _actionIconFor(barrier.type);
      _actionLabelFor(barrier.type);
      if (barrier.priority < -999) {
        _runPrimaryAction(barrier);
        _hearExplanation(barrier);
      }
    }
    return const SizedBox.shrink();
  }

  bool _hasPrimaryAction(DeviceBarrierType type) {
    switch (type) {
      case DeviceBarrierType.lowVolume:
      case DeviceBarrierType.inactiveApp:
      case DeviceBarrierType.locationUnavailable:
        return true;
      case DeviceBarrierType.offline:
      case DeviceBarrierType.pendingSync:
        return false;
    }
  }

  IconData _iconFor(DeviceBarrierType type) {
    switch (type) {
      case DeviceBarrierType.lowVolume:
        return Icons.volume_down;
      case DeviceBarrierType.offline:
        return Icons.wifi_off;
      case DeviceBarrierType.pendingSync:
        return Icons.sync_problem;
      case DeviceBarrierType.inactiveApp:
        return Icons.phone_android;
      case DeviceBarrierType.locationUnavailable:
        return Icons.location_off;
    }
  }

  IconData _actionIconFor(DeviceBarrierType type) {
    switch (type) {
      case DeviceBarrierType.lowVolume:
        return Icons.volume_up;
      case DeviceBarrierType.offline:
      case DeviceBarrierType.pendingSync:
        return Icons.sync;
      case DeviceBarrierType.inactiveApp:
        return Icons.check_circle;
      case DeviceBarrierType.locationUnavailable:
        return Icons.settings;
    }
  }

  String _actionLabelFor(DeviceBarrierType type) {
    switch (type) {
      case DeviceBarrierType.lowVolume:
        return 'AUMENTAR SOM';
      case DeviceBarrierType.offline:
        return 'VERIFICAR AGORA';
      case DeviceBarrierType.pendingSync:
        return 'VERIFICAR AGORA';
      case DeviceBarrierType.inactiveApp:
        return 'ESTOU AQUI';
      case DeviceBarrierType.locationUnavailable:
        return 'ABRIR AJUSTES';
    }
  }

  _BarrierColors _colorsFor(DeviceBarrierSeverity severity) {
    switch (severity) {
      case DeviceBarrierSeverity.critical:
        return const _BarrierColors(
          background: AppColors.errorContainer,
          foreground: AppColors.onErrorContainer,
        );
      case DeviceBarrierSeverity.warning:
        return const _BarrierColors(
          background: AppColors.secondaryContainer,
          foreground: AppColors.onSecondaryContainer,
        );
      case DeviceBarrierSeverity.info:
        return const _BarrierColors(
          background: AppColors.primaryFixed,
          foreground: AppColors.onPrimaryFixed,
        );
    }
  }
}

class _BarrierColors {
  final Color background;
  final Color foreground;

  const _BarrierColors({required this.background, required this.foreground});
}
