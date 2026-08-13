import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';
import '../widgets/responsive_layout.dart';

class ElderlyOnboardingScreen extends StatefulWidget {
  const ElderlyOnboardingScreen({super.key});

  @override
  State<ElderlyOnboardingScreen> createState() =>
      _ElderlyOnboardingScreenState();
}

class _ElderlyOnboardingScreenState extends State<ElderlyOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.waving_hand,
      title: 'Bem-vindo ao\nLembrete Amigo!',
      subtitle:
          'Eu sou o Alex. Um assistente por voz que vai te acompanhar em cada momento do dia.',
      ttsMessage:
          'Olá! Seja muito bem-vindo ao Lembrete Amigo. Eu sou o Alex e vou te ajudar a lembrar das suas atividades do dia a dia.',
    ),
    _OnboardingStep(
      icon: Icons.volume_up,
      title: 'Lembretes em\nSom Alto',
      subtitle:
          'O aplicativo fala em voz alta sobre seus remédios, refeições e exercícios. Os botões são grandes e fáceis de tocar.',
      ttsMessage:
          'Eu vou ler todos os seus lembretes em voz alta na hora certa. Os botões na tela são grandes e coloridos para você tocar sem dificuldade.',
    ),
    _OnboardingStep(
      icon: Icons.mic,
      title: 'Lembrete por Voz',
      subtitle:
          'Para criar um novo lembrete rápido, basta tocar no grande botão amarelo de microfone no meio da tela.',
      ttsMessage:
          'No meio da tela inicial, você pode tocar no grande círculo amarelo de microfone para gravar um novo lembrete com a sua voz.',
    ),
    _OnboardingStep(
      icon: Icons.local_hospital,
      title: 'Ligar para a\nAmbulância',
      subtitle:
          'Se não estiver se sentindo bem ou em caso de emergência, você pode tocar no botão da Ambulância para pedir socorro rápido.',
      ttsMessage:
          'Se você não estiver se sentindo bem ou tiver uma emergência, pode ir até a tela de ajuda e tocar no botão vermelho para ligar para a Ambulância imediatamente.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakStep(0);
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _pageController.dispose();
    super.dispose();
  }

  void _speakStep(int index) {
    if (index < _steps.length) {
      TTSService.instance.falar(_steps[index].ttsMessage, caller: this);
    }
  }

  void _goNext() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      TTSService.instance.parar(caller: this);
      Navigator.pushReplacementNamed(context, '/elderly-pairing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AlexFloatingHelpButton(
        key: ValueKey(_currentPage),
        textoExplicacao: _steps[_currentPage].ttsMessage,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Row(
              children: [
                if (_currentPage > 0)
                  InkWell(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      TTSService.instance.parar(caller: this);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/welcome',
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ),
                const Spacer(),
                _buildDots(),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _speakStep(index);
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return ResponsiveScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    maxContentWidth: 720,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Icon(step.icon, size: 80, color: AppColors.primary),
                        const SizedBox(height: 24),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    minimumSize: Size.fromHeight(
                      context.isCompactHeight ? 72 : 96,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _currentPage < _steps.length - 1
                              ? 'Continuar'
                              : 'Entendi',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: context.isCompactHeight ? 24 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        width: context.isCompactHeight ? 52 : 64,
                        height: context.isCompactHeight ? 52 : 64,
                        decoration: BoxDecoration(
                          color: AppColors.onSecondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _currentPage < _steps.length - 1
                              ? Icons.arrow_forward
                              : Icons.check_circle,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_steps.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ttsMessage;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ttsMessage,
  });
}
