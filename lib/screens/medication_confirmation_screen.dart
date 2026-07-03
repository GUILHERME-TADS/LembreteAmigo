import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class MedicationConfirmationScreen extends StatelessWidget {
  const MedicationConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? message = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 24),
                    const Text(
                      'MUITO BEM!',
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message ?? 'Você tomou seu remédio.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 1.5, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    const MeExplicaButton(
                      textoExplicacao: 'Parabéns! Você concluiu a sua tarefa com sucesso. Para voltar para a tela de início, aperte no botão amarelo de VOLTAR PARA O INÍCIO.',
                    ),
                    const Spacer(),
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixedDim,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
                        ],
                      ),
                      child: const Icon(Icons.check_circle, size: 64, color: AppColors.onTertiaryFixedVariant),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixedDim.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.eco, size: 80, color: AppColors.onTertiaryFixedVariant),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        onPressed: () {
                          TTSService.instance.parar();
                          Navigator.pushNamedAndRemoveUntil(context, '/elderly-home', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('VOLTAR PARA O INÍCIO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
          onPressed: () {
            TTSService.instance.parar();
            Navigator.pop(context);
          },
        ),
        Container(
          width: 48, height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: AppColors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        const Text(
          'Meu Amigo',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            TTSService.instance.parar();
            TTSService.instance.falar(
              'Parabéns! Você concluiu. Aperte o botão para voltar ao início.',
            );
          },
          child: const AlexAvatar(size: 40),
        ),
      ],
    );
  }
}

