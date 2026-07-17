import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class MeExplicaButton extends StatefulWidget {
  final String textoExplicacao;
  final VoidCallback? onTapped;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const MeExplicaButton({
    super.key,
    required this.textoExplicacao,
    this.onTapped,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<MeExplicaButton> createState() => _MeExplicaButtonState();
}

class _MeExplicaButtonState extends State<MeExplicaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TTSService.instance.speakingNotifier,
      builder: (context, isGlobalSpeaking, child) {
        final isThisSpeaking =
            isGlobalSpeaking && TTSService.instance.activeCaller == this;

        _syncAnimation(isThisSpeaking);

        final txtColor = isThisSpeaking
            ? AppColors.onSecondaryFixedVariant
            : (widget.textColor ?? AppColors.primary);
        final bg = isThisSpeaking
            ? AppColors.secondaryFixed
            : (widget.backgroundColor ?? AppColors.primaryFixed);
        final border = isThisSpeaking
            ? AppColors.secondaryFixedDim
            : (widget.borderColor ?? AppColors.primary);

        return GestureDetector(
          onTap: () => _handleTap(isThisSpeaking),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final scale = isThisSpeaking
                  ? 1.0 + (_animationController.value * 0.03)
                  : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.touchTargetMin,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: border, width: 2),
                    boxShadow: isThisSpeaking
                        ? [
                            BoxShadow(
                              color: AppColors.secondaryFixed.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 8 * _animationController.value,
                              spreadRadius: 2 * _animationController.value,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isThisSpeaking
                            ? Icons.stop_circle
                            : Icons.volume_up,
                        color: txtColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isThisSpeaking ? 'Parar de ouvir' : 'Me explica',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: txtColor,
                          ),
                        ),
                      ),
                      if (isThisSpeaking) ...[
                        const SizedBox(width: 8),
                        _buildWaveIndicator(txtColor),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleTap(bool isThisSpeaking) {
    HapticFeedback.lightImpact();
    if (isThisSpeaking) {
      TTSService.instance.parar(caller: this);
      return;
    }

    TTSService.instance.parar();
    widget.onTapped?.call();
    TTSService.instance.falar(widget.textoExplicacao, caller: this);
  }

  void _syncAnimation(bool isThisSpeaking) {
    if (isThisSpeaking && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (!isThisSpeaking && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  Widget _buildWaveIndicator(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: 10 + (index * 4) * _animationController.value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
