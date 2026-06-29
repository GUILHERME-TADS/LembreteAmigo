import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class AlexAvatar extends StatefulWidget {
  final bool isListening;
  final double size;
  final bool animate;

  const AlexAvatar({
    super.key,
    this.isListening = false,
    this.size = 120.0,
    this.animate = true,
  });

  @override
  State<AlexAvatar> createState() => _AlexAvatarState();
}

class _AlexAvatarState extends State<AlexAvatar> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _idlePulseController;
  late Animation<double> _scaleAnimation;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _idlePulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate) {
      TTSService.instance.speakingNotifier.addListener(_onSpeakingChanged);
    }
    
    if ((widget.animate && TTSService.instance.isSpeaking) || widget.isListening) {
      _stopIdlePulsing();
    } else {
      _startIdleTimer();
    }

    if (widget.animate && TTSService.instance.isSpeaking) {
      _animationController.repeat(reverse: true);
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && !widget.isListening && !TTSService.instance.isSpeaking) {
        _idlePulseController.repeat(reverse: true);
      }
    });
  }

  void _stopIdlePulsing() {
    _idleTimer?.cancel();
    if (_idlePulseController.isAnimating) {
      _idlePulseController.stop();
      _idlePulseController.reset();
    }
  }

  @override
  void didUpdateWidget(AlexAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _stopIdlePulsing();
      } else {
        _startIdleTimer();
      }
    }
  }

  void _onSpeakingChanged() {
    if (mounted) {
      final isSpeaking = TTSService.instance.isSpeaking;
      if (isSpeaking) {
        _animationController.repeat(reverse: true);
        _stopIdlePulsing();
      } else {
        _animationController.stop();
        _animationController.reset();
        if (!widget.isListening) {
          _startIdleTimer();
        }
      }
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      TTSService.instance.speakingNotifier.removeListener(_onSpeakingChanged);
    }
    _idleTimer?.cancel();
    _animationController.dispose();
    _idlePulseController.dispose();
    super.dispose();
  }

  Color _getBorderColor(bool isSpeaking) {
    if (widget.isListening) {
      return const Color(0xFF0061A4); // azul escuta
    }
    if (isSpeaking) {
      return const Color(0xFFFCD400); // amarelo fala
    }
    return const Color(0xFFABC7FF); // azul padrão
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;

    return ValueListenableBuilder<bool>(
      valueListenable: TTSService.instance.speakingNotifier,
      builder: (context, isSpeakingVal, _) {
        final bool isSpeaking = widget.animate && isSpeakingVal;
        final borderColor = _getBorderColor(isSpeaking);
        final bool isActiveState = widget.isListening || isSpeaking;

        return ScaleTransition(
          scale: _scaleAnimation,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Headband do Headset (Arco superior)
                Positioned(
                  top: size * 0.02,
                  left: size * 0.07,
                  right: size * 0.07,
                  height: size * 0.45,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: size * 0.05,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(size * 0.45),
                      ),
                    ),
                  ),
                ),

                // 2. Protetores Auriculares do Headset (Earcups laterais)
                // Lado Esquerdo
                Positioned(
                  left: size * 0.01,
                  top: size * 0.28,
                  width: size * 0.12,
                  height: size * 0.35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(size * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: size * 0.03,
                          offset: Offset(-size * 0.01, size * 0.01),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.04,
                        height: size * 0.12,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(size * 0.02),
                        ),
                      ),
                    ),
                  ),
                ),

                // Lado Direito
                Positioned(
                  right: size * 0.01,
                  top: size * 0.28,
                  width: size * 0.12,
                  height: size * 0.35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(size * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: size * 0.03,
                          offset: Offset(size * 0.01, size * 0.01),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.04,
                        height: size * 0.12,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(size * 0.02),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Rosto (Círculo Central)
                Positioned(
                  left: size * 0.11,
                  right: size * 0.11,
                  top: size * 0.11,
                  bottom: size * 0.11,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFF3F7FA),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: borderColor,
                        width: size * 0.05,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isListening
                              ? const Color(0xFF0061A4).withValues(alpha: 0.35)
                              : isSpeaking
                                  ? const Color(0xFFFCD400).withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.08),
                          blurRadius: isActiveState ? size * 0.12 : size * 0.06,
                          spreadRadius: isActiveState ? size * 0.02 : 0,
                          offset: Offset(0, size * 0.03),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Olhos do Alex
                        Positioned(
                          top: size * 0.22,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildEye(isSpeaking, widget.isListening, size),
                              SizedBox(width: size * 0.16),
                              _buildEye(isSpeaking, widget.isListening, size),
                            ],
                          ),
                        ),

                        // Bochechas rosadas (Blushing)
                        Positioned(
                          top: size * 0.33,
                          left: size * 0.10,
                          child: Container(
                            width: size * 0.11,
                            height: size * 0.055,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB5B5).withValues(alpha: 0.55),
                              borderRadius: BorderRadius.all(Radius.circular(size * 0.03)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: size * 0.33,
                          right: size * 0.10,
                          child: Container(
                            width: size * 0.11,
                            height: size * 0.055,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB5B5).withValues(alpha: 0.55),
                              borderRadius: BorderRadius.all(Radius.circular(size * 0.03)),
                            ),
                          ),
                        ),

                        // Boca do Alex
                        Positioned(
                          bottom: size * 0.16,
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final scale = _animationController.value;
                              return _buildMouth(isSpeaking, widget.isListening, scale, size);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3.5. Braço do Microfone (Boom arm) - Renderizado por cima do rosto, começa no fone externo e entra bem no rosto
                Positioned(
                  left: size * 0.07,
                  top: size * 0.44,
                  width: size * 0.35,
                  height: size * 0.25,
                  child: CustomPaint(
                    painter: _MicArmPainter(
                      color: AppColors.primary,
                      strokeWidth: size * 0.025,
                      borderColor: borderColor,
                      size: size,
                    ),
                  ),
                ),

                // 4. Tag status - Ouvindo / Falando (Só exibe para tamanhos >= 100)
                if (size >= 100) ...[
                  if (widget.isListening)
                    Positioned(
                      top: -size * 0.02,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size * 0.08,
                          vertical: size * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0061A4),
                          borderRadius: BorderRadius.circular(size * 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hearing, color: Colors.white, size: size * 0.08),
                            SizedBox(width: size * 0.02),
                            Text(
                              'Ouvindo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: size * 0.07,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isSpeaking && !widget.isListening)
                    Positioned(
                      top: -size * 0.02,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size * 0.08,
                          vertical: size * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCD400),
                          borderRadius: BorderRadius.circular(size * 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up, color: const Color(0xFF6E5C00), size: size * 0.08),
                            SizedBox(width: size * 0.02),
                            Text(
                              'Falando',
                              style: TextStyle(
                                color: const Color(0xFF6E5C00),
                                fontSize: size * 0.07,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEye(bool isSpeaking, bool isListening, double size) {
    if (isListening) {
      return Container(
        width: size * 0.09,
        height: size * 0.09,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1A2C),
          shape: BoxShape.circle,
        ),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: size * 0.03,
            height: size * 0.03,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    if (isSpeaking) {
      return CustomPaint(
        size: Size(size * 0.09, size * 0.045),
        painter: _HappyEyePainter(
          color: const Color(0xFF0F1A2C),
          strokeWidth: size * 0.022,
        ),
      );
    }

    return Container(
      width: size * 0.09,
      height: size * 0.09,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1A2C),
        shape: BoxShape.circle,
      ),
      child: Align(
        alignment: const Alignment(0.3, -0.3),
        child: Container(
          width: size * 0.025,
          height: size * 0.025,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildMouth(bool isSpeaking, bool isListening, double scale, double size) {
    if (isListening) {
      return Container(
        width: size * 0.09,
        height: size * 0.09,
        decoration: BoxDecoration(
          color: const Color(0xFFBA1A1A),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0F1A2C), width: size * 0.02),
        ),
      );
    }

    if (isSpeaking) {
      final heightFactor = 0.035 + (scale * 0.075);
      return Container(
        width: size * 0.13,
        height: size * heightFactor,
        decoration: BoxDecoration(
          color: const Color(0xFFBA1A1A),
          borderRadius: BorderRadius.circular(size * 0.06),
          border: Border.all(color: const Color(0xFF0F1A2C), width: size * 0.02),
        ),
      );
    }

    return CustomPaint(
      size: Size(size * 0.14, size * 0.07),
      painter: _SmilePainter(
        color: const Color(0xFF0F1A2C),
        strokeWidth: size * 0.02,
      ),
    );
  }
}

class _HappyEyePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _HappyEyePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width / 2,
      -size.height * 0.3,
      size.width,
      size.height,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SmilePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SmilePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 1.2,
      size.width,
      size.height * 0.2,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicArmPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Color borderColor;
  final double size;

  _MicArmPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderColor,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Desenha o braço curvo do microfone
    final paintArm = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.95,
      size.width * 0.88,
      size.height * 0.84,
    );

    canvas.drawPath(path, paintArm);

    // Desenha a cápsula do microfone na ponta
    final paintTip = Paint()
      ..color = borderColor // Usa a cor de status (azul/amarelo/etc) para a ponta brilhar!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.84),
      this.size * 0.035,
      paintTip,
    );

    // Borda escura ao redor da ponta para contraste
    final paintTipBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = this.size * 0.015;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.84),
      this.size * 0.035,
      paintTipBorder,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
