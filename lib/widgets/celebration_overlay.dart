import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Overlay visual de celebração e reforço positivo para idosos.
/// Exibe partículas brilhantes / confetes e um selo comemorativo suave.
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback? onComplete;
  final String title;
  final String subtitle;

  const CelebrationOverlay({
    super.key,
    this.onComplete,
    this.title = 'Muito Bem! 🌟',
    this.subtitle = 'Você cuidou da sua saúde hoje!',
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Muito Bem! 🌟',
    String subtitle = 'Você cuidou da sua saúde hoje!',
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar celebração',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return CelebrationOverlay(
          title: title,
          subtitle: subtitle,
          onComplete: () => Navigator.of(context, rootNavigator: true).pop(),
        );
      },
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    for (int i = 0; i < 35; i++) {
      _particles.add(
        _Particle(
          x: 0.5 + (_random.nextDouble() - 0.5) * 0.4,
          y: 0.4 + (_random.nextDouble() - 0.5) * 0.2,
          dx: (_random.nextDouble() - 0.5) * 350,
          dy: -120 - _random.nextDouble() * 250,
          size: 6 + _random.nextDouble() * 8,
          color: _randomParticleColor(),
          rotation: _random.nextDouble() * math.pi * 2,
        ),
      );
    }

    _controller.forward().then((_) {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  Color _randomParticleColor() {
    final colors = [
      const Color(0xFFFFD54F), // Dourado
      const Color(0xFF81C784), // Verde suave
      const Color(0xFF64B5F6), // Azul céu
      const Color(0xFFFF8A65), // Laranja quente
      const Color(0xFFBA68C8), // Violeta alegre
      Colors.white,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onComplete != null) widget.onComplete!();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final scale = (math.sin(t * math.pi * 0.8) * 1.05).clamp(0.0, 1.0);
            final opacity = (1.0 - t * 0.3).clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Partículas voando
                RepaintBoundary(
                  child: CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(particles: _particles, progress: t),
                  ),
                ),

                // Card Central de Celebração
                Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(
                          color: const Color(0xFFFFD54F),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B5E20),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF37474F),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final double rotation;

  _Particle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentX = p.x * size.width + p.dx * progress;
      final currentY =
          p.y * size.height + p.dy * progress + 300 * progress * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + progress * math.pi * 3);
      canvas.drawCircle(Offset.zero, p.size / 2, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
