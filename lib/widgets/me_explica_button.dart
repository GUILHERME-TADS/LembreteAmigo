import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';

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

class _MeExplicaButtonState extends State<MeExplicaButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TTSService.instance.speakingNotifier,
      builder: (context, isGlobalSpeaking, child) {
        // Verifica se este botão específico é o autor da fala ativa por referência de widget ou texto
        final isThisSpeaking = isGlobalSpeaking &&
            (TTSService.instance.activeCaller == widget ||
             TTSService.instance.activeText == widget.textoExplicacao);

        final txtColor = isThisSpeaking
            ? AppColors.onSecondaryFixedVariant
            : (widget.textColor ?? AppColors.primary);
            
        final bg = isThisSpeaking
            ? AppColors.secondaryFixed
            : (widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.08));
            
        final border = isThisSpeaking
            ? AppColors.secondaryFixedDim
            : (widget.borderColor ?? AppColors.primary.withValues(alpha: 0.15));

        return GestureDetector(
          onTap: () {
            if (isThisSpeaking) {
              // Se já estiver tocando esta explicação, para a fala
              TTSService.instance.parar();
            } else {
              // Interrompe qualquer áudio/fala ativa e inicia esta
              TTSService.instance.parar();
              if (widget.onTapped != null) {
                widget.onTapped!();
              }
              TTSService.instance.falar(
                widget.textoExplicacao,
                caller: widget,
              );
            }
          },
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              // Efeito sutil de escala no botão ativo
              final double scale = isThisSpeaking ? 1.0 + (_animationController.value * 0.03) : 1.0;
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.touchTargetMin,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: border,
                      width: 2.0,
                    ),
                    boxShadow: isThisSpeaking ? [
                      BoxShadow(
                        color: AppColors.secondaryFixed.withValues(alpha: 0.4),
                        blurRadius: 8 * _animationController.value,
                        spreadRadius: 2 * _animationController.value,
                      )
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isThisSpeaking ? Icons.volume_off : Icons.record_voice_over,
                        color: txtColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isThisSpeaking ? 'Parar explicação' : 'Me explica',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: txtColor,
                        ),
                      ),
                      if (isThisSpeaking) ...[
                        const SizedBox(width: 8),
                        _buildWaveIndicator(txtColor),
                      ]
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
