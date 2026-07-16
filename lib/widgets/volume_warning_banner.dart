import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../services/volume_service.dart';
import '../theme/app_theme.dart';

class VolumeWarningBanner extends StatefulWidget {
  const VolumeWarningBanner({super.key});

  @override
  State<VolumeWarningBanner> createState() => _VolumeWarningBannerState();
}

class _VolumeWarningBannerState extends State<VolumeWarningBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _volumePercentage = 100;
  bool _isAdjusting = false;
  bool _hasSpokenWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVolume();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkVolume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVolume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _checkVolume() async {
    final vol = await VolumeService.getVolumePercentage();
    if (!mounted) return;
    if (vol != _volumePercentage) {
      setState(() {
        _volumePercentage = vol;
      });
    }

    if (VolumeService.isLow(vol) && !_hasSpokenWarning) {
      _hasSpokenWarning = true;
    } else if (!VolumeService.isLow(vol)) {
      _hasSpokenWarning = false;
    }
  }

  Future<void> _increaseVolume() async {
    if (_isAdjusting) return;
    setState(() => _isAdjusting = true);
    final vol = await VolumeService.setSafeVolume();
    if (!mounted) return;
    setState(() {
      _volumePercentage = vol;
      _isAdjusting = false;
    });
    await TTSService.instance.falar(
      'Pronto. O volume foi ajustado. Agora voce deve conseguir ouvir os lembretes.',
      caller: this,
    );
  }



  Future<void> _speakWarning() async {
    await TTSService.instance.falar(
      'Som do celular baixo. Aumente o som para não perder lembretes importantes. Se o botão não mudar o volume, use os botões na lateral do seu celular.',
      caller: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!VolumeService.isLow(_volumePercentage)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: AppColors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _volumePercentage == 0 ? Icons.volume_mute : Icons.volume_down,
                color: AppColors.onErrorContainer,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SOM DO CELULAR BAIXO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onErrorContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '$_volumePercentage%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: LinearProgressIndicator(
                value: _volumePercentage / 100.0,
                backgroundColor: AppColors.onErrorContainer.withValues(
                  alpha: 0.2,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _volumePercentage <= 15 ? AppColors.error : Colors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aumente o som para nao perder lembretes importantes.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAdjusting ? null : _increaseVolume,
                  icon: Icon(
                    _isAdjusting ? Icons.hourglass_empty : Icons.volume_up,
                  ),
                  label: Text(_isAdjusting ? 'AJUSTANDO...' : 'AUMENTAR SOM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.onErrorContainer,
                    foregroundColor: AppColors.errorContainer,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                width: 58,
                child: OutlinedButton(
                  onPressed: _speakWarning,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onErrorContainer,
                    side: const BorderSide(color: AppColors.onErrorContainer, width: 2),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.volume_up, size: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Se o botao nao mudar o volume, use os botoes laterais do celular.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
