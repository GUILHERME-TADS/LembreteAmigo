import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReinforcementAlertScreen extends StatelessWidget {
  const ReinforcementAlertScreen({super.key});

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
                      'HORA DA ATIVIDADE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildVoiceVisualization(),
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
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Lembrete Amigo',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.primaryContainer, width: 2),
              ),
            ),
            child: const Icon(Icons.person, color: AppColors.primaryContainer),
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
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 160,
          height: 160,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.secondary, width: 4),
          ),
          child: const Icon(
            Icons.directions_walk,
            size: 96,
            color: AppColors.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceVisualization() {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Container(
              width: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              height: [24, 40, 32, 48, 24][i].toDouble(),
            )),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up, size: 24, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'OUVINDO MENSAGEM...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                color: AppColors.primary,
              ),
            ),
          ],
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
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_walk, color: AppColors.onPrimaryContainer, size: 40),
          ),
          const SizedBox(width: 24),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Caminhada Leve',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Vamos caminhar por 15 minutos.',
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
