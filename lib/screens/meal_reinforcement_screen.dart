import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MealReinforcementScreen extends StatelessWidget {
  const MealReinforcementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildPulsingIcon(),
                    const SizedBox(height: 32),
                    const Text(
                      'OLÁ! VAMOS LÁ?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'HORA DE COMER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Icon(Icons.volume_up, size: 24, color: AppColors.mealsColor),
                    const SizedBox(height: 8),
                    const Text(
                      'OUVINDO MENSAGEM...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.mealsColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActivityCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildCtaButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.mealsColor, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Hora de Comer',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.mealsColor),
          ),
          const Spacer(),
          const Icon(Icons.volume_up, color: AppColors.mealsColor, size: 28),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            child: Row(
              children: List.generate(4, (i) => Container(
                width: 4,
                height: [16, 24, 12, 20][i].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.mealsColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200, height: 200,
          decoration: BoxDecoration(
            color: AppColors.mealsColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 160, height: 160,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.mealsColor, width: 4),
          ),
          child: const Icon(Icons.restaurant, size: 96, color: AppColors.mealsColor),
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mealsColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.mealsColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.mealsColor, size: 40),
          ),
          const SizedBox(width: 24),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hora de Comer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sua refeição está te esperando.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.play_circle, size: 32),
          label: const Text(
            'VER AGORA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
