import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

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
      subtitle: 'Eu sou o Alex, assistente virtual que vai te ajudar no dia a dia.',
      ttsMessage: 'Ola, seja muito bem-vindo! Eu sou o Alex, seu assistente virtual. Vou te ajudar a lembrar dos seus compromissos e atividades.',
    ),
    _OnboardingStep(
      icon: Icons.campaign,
      title: 'Lembretes\nem Voz Alta',
      subtitle: 'O aplicativo vai falar com voce sobre remedios, refeicoes, exercicios e muito mais.',
      ttsMessage: 'Eu vou falar os seus lembretes em voz alta para facilitar o seu dia. Voce vai ouvir sobre remedios, refeicoes, exercicios e outros cuidados.',
    ),
    _OnboardingStep(
      icon: Icons.mic,
      title: 'Comandos\nde Voz',
      subtitle: 'Responda falando! Diga "ja tomei", "adiar" ou "me explica" que eu entendo.',
      ttsMessage: 'Voce pode responder falando comigo. Diga "ja tomei" quando concluir algo, "adiar" para deixar para depois, ou "me explica" que eu repito a informacao.',
    ),
    _OnboardingStep(
      icon: Icons.emergency,
      title: 'Botao de\nEmergencia',
      subtitle: 'Se precisar de ajuda, aperte o botao vermelho. Sua familia sera avisada.',
      ttsMessage: 'Se voce precisar de ajuda, aperte o botao vermelho de emergencia. Sua familia e cuidadores serao avisados imediatamente.',
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
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 36),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      TTSService.instance.parar(caller: this);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 36),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
                        Icon(step.icon, size: 80, color: AppColors.primary),
                        const SizedBox(height: 24),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        MeExplicaButton(
                          textoExplicacao: step.ttsMessage,
                        ),
                        const Spacer(flex: 2),
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
                height: 96,
                child: ElevatedButton(
                  onPressed: _goNext,
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
                      Text(
                        _currentPage < _steps.length - 1
                            ? 'Continuar'
                            : 'Entendi',
                        style: const TextStyle(
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
