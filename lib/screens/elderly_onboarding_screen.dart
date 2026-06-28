import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class ElderlyOnboardingScreen extends StatefulWidget {
  const ElderlyOnboardingScreen({super.key});

  @override
  State<ElderlyOnboardingScreen> createState() => _ElderlyOnboardingScreenState();
}

class _ElderlyOnboardingScreenState extends State<ElderlyOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Eu vou falar os seus lembretes para te ajudar. Aperte o botão amarelo de entendi para começar.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bem-vindo ao Lembrete Amigo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Eu vou falar com você e ouvir o que você precisa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () {
                        TTSService.instance.falar(
                          'Eu vou falar os seus lembretes para te ajudar. Aperte o botão amarelo de entendi para começar.',
                          caller: this,
                        );
                      },
                      child: const AlexAvatar(size: 140),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.outlineVariant, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.onTertiaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.campaign, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'O aplicativo vai ler os seus lembretes em voz alta para facilitar o seu dia!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 96,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/elderly-pairing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Entendi',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: AppColors.onSecondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle, size: 32, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
