import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'alex_avatar.dart';

class AlexFloatingHelpButton extends StatefulWidget {
  final String textoExplicacao;
  final VoidCallback? onTapped;

  const AlexFloatingHelpButton({
    super.key,
    required this.textoExplicacao,
    this.onTapped,
  });

  @override
  State<AlexFloatingHelpButton> createState() => _AlexFloatingHelpButtonState();
}

class _AlexFloatingHelpButtonState extends State<AlexFloatingHelpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _glowController.dispose();
    super.dispose();
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
    if (isThisSpeaking && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!isThisSpeaking && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TTSService.instance.speakingNotifier,
      builder: (context, isGlobalSpeaking, child) {
        final isThisSpeaking =
            isGlobalSpeaking && TTSService.instance.activeCaller == this;

        _syncAnimation(isThisSpeaking);

        return Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            // Speech bubble next to Alex
            Positioned(
              right: 76,
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: 1.0,
                child: GestureDetector(
                  onTap: () => _handleTap(isThisSpeaking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isThisSpeaking
                          ? AppColors.secondaryFixed
                          : AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      isThisSpeaking ? 'Parar de ouvir' : 'Me explica',
                      style: TextStyle(
                        color: isThisSpeaking
                            ? AppColors.onSecondaryFixedVariant
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Alex Avatar button itself
            GestureDetector(
              onTap: () => _handleTap(isThisSpeaking),
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isThisSpeaking
                          ? [
                              BoxShadow(
                                color: AppColors.secondaryFixed.withValues(
                                  alpha: 0.4 + (_glowController.value * 0.3),
                                ),
                                blurRadius: 12 + (_glowController.value * 12),
                                spreadRadius: 2 + (_glowController.value * 6),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: AlexAvatar(
                      size: 68,
                      animate: isThisSpeaking || isGlobalSpeaking,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
