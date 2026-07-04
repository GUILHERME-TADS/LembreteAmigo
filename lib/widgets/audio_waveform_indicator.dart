import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AudioWaveformIndicator extends StatefulWidget {
  final bool isListening;
  const AudioWaveformIndicator({super.key, required this.isListening});

  @override
  State<AudioWaveformIndicator> createState() => _AudioWaveformIndicatorState();
}

class _AudioWaveformIndicatorState extends State<AudioWaveformIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isListening) return const SizedBox.shrink();

    final isHighContrast = Theme.of(context).colorScheme.primary == Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isHighContrast ? Colors.white : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighContrast ? Colors.black : AppColors.primary.withValues(alpha: 0.15),
          width: isHighContrast ? 3 : 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            color: isHighContrast ? Colors.black : AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            'OUVINDO...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isHighContrast ? Colors.black : AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 20),
          // Waves
          SizedBox(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final double progress = (_controller.value + (index * 0.18)) % 1.0;
                    final double sineValue = 0.25 + 0.75 * math.sin(progress * 2 * math.pi).abs();
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 36 * sineValue,
                      decoration: BoxDecoration(
                        color: isHighContrast ? Colors.black : AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
