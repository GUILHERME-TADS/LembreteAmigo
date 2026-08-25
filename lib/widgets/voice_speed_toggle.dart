import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Botão acessível para alternar rapidamente a velocidade da voz do Alex (Normal vs Devagar).
class VoiceSpeedToggle extends StatefulWidget {
  final bool compact;

  const VoiceSpeedToggle({super.key, this.compact = false});

  @override
  State<VoiceSpeedToggle> createState() => _VoiceSpeedToggleState();
}

class _VoiceSpeedToggleState extends State<VoiceSpeedToggle> {
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentRate();
  }

  void _checkCurrentRate() {
    final rate = TTSService.instance.voiceProfile.speechRate;
    setState(() {
      _isSlow = rate <= 0.35;
    });
  }

  Future<void> _toggleSpeed() async {
    HapticFeedback.mediumImpact();
    final newSlow = !_isSlow;
    final newRate = newSlow ? 0.30 : 0.45;
    final currentProfile = TTSService.instance.voiceProfile;
    final updatedProfile = currentProfile.copyWith(speechRate: newRate);

    await TTSService.instance.updateProfile(updatedProfile);
    if (mounted) {
      setState(() {
        _isSlow = newSlow;
      });
    }

    final message = newSlow
        ? 'Velocidade ajustada para falar mais devagar.'
        : 'Velocidade da voz normal.';
    await TTSService.instance.falar(message, caller: this);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Semantics(
        button: true,
        label: _isSlow
            ? 'Velocidade de voz lenta ativada. Toque para velocidade normal.'
            : 'Velocidade de voz normal. Toque para falar mais devagar.',
        child: InkWell(
          onTap: _toggleSpeed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isSlow
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _isSlow ? AppColors.primary : AppColors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSlow ? Icons.slow_motion_video_rounded : Icons.speed_rounded,
                  size: 18,
                  color: _isSlow ? AppColors.onPrimaryContainer : AppColors.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSlow ? 'Devagar' : 'Normal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _isSlow ? AppColors.onPrimaryContainer : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: _isSlow
          ? 'Voz está falando devagar. Toque para velocidade normal.'
          : 'Voz está em velocidade normal. Toque para falar mais devagar.',
      child: GestureDetector(
        onTap: _toggleSpeed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isSlow
                ? AppColors.primaryContainer
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: _isSlow
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.7),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSlow ? Icons.slow_motion_video_rounded : Icons.speed_rounded,
                size: 26,
                color: _isSlow ? AppColors.primary : AppColors.onSurface,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSlow ? 'Falar Devagar (Ativo)' : 'Falar Normal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _isSlow ? AppColors.onPrimaryContainer : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Toque para alternar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
