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
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _entryController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  static Offset _globalDragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _glowController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _handleTap(bool isThisSpeaking) {
    HapticFeedback.mediumImpact();
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

        final size = MediaQuery.of(context).size;
        final isFlipped = _globalDragOffset.dx < -(size.width / 2);

        final widgetStack = GestureDetector(
          onPanUpdate: (details) {
            final size = MediaQuery.of(context).size;
            setState(() {
              _globalDragOffset += details.delta;
              _globalDragOffset = Offset(
                _globalDragOffset.dx.clamp(-size.width + 100, 0.0),
                _globalDragOffset.dy.clamp(-size.height + 280, 0.0),
              );
            });
          },
          child: Padding(
            padding: EdgeInsets.only(
              right: -_globalDragOffset.dx,
              bottom: -_globalDragOffset.dy,
            ),
            child: Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
            // Speech bubble next to Alex
            Positioned(
              right: isFlipped ? null : 80,
              left: isFlipped ? 80 : null,
              bottom: 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: 1.0,
                child: GestureDetector(
                  onTap: () => _handleTap(isThisSpeaking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isThisSpeaking
                          ? AppColors.error
                          : AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isFlipped ? 4 : 20),
                        bottomRight: Radius.circular(isFlipped ? 20 : 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isThisSpeaking
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isThisSpeaking ? 'PARAR DE OUVIR' : 'ME EXPLICA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
                      animate: true,
                      activeCaller: this,
                    ),
                  );
                },
              ),
            ),
          ],
            ),
          ),
        );

        return AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: widgetStack,
        );
      },
    );
  }
}
