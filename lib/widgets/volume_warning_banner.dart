import 'dart:async';
import 'package:flutter/material.dart';
import '../services/volume_service.dart';
import '../theme/app_theme.dart';

class VolumeWarningBanner extends StatefulWidget {
  const VolumeWarningBanner({super.key});

  @override
  State<VolumeWarningBanner> createState() => _VolumeWarningBannerState();
}

class _VolumeWarningBannerState extends State<VolumeWarningBanner> {
  Timer? _timer;
  int _volumePercentage = 100;

  @override
  void initState() {
    super.initState();
    _checkVolume();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkVolume());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVolume() async {
    final vol = await VolumeService.getVolumePercentage();
    if (mounted && vol != _volumePercentage) {
      setState(() {
        _volumePercentage = vol;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_volumePercentage >= 50) {
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
              const Text(
                'SOM DO CELULAR BAIXO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onErrorContainer,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
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
          // Barra de progresso visual do volume
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: LinearProgressIndicator(
                value: _volumePercentage / 100.0,
                backgroundColor: AppColors.onErrorContainer.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _volumePercentage <= 15 ? AppColors.error : Colors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aperte os botões de volume na lateral do celular para aumentar o som!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
