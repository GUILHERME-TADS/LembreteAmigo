import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../widgets/index.dart';
import '../services/tts_service.dart';

class PostponeConfirmationScreen extends StatefulWidget {
  const PostponeConfirmationScreen({super.key});

  @override
  State<PostponeConfirmationScreen> createState() => _PostponeConfirmationScreenState();
}

class _PostponeConfirmationScreenState extends State<PostponeConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  String? _categoria;
  String _tipo = 'adiar';
  bool _hasSpokenInitial = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _categoria = args['categoria'] as String?;
      _tipo = args['tipo'] as String? ?? 'adiar';
    } else if (args is Lembrete) {
      _categoria = args.categoria;
      _tipo = 'adiar';
    }

    if (!_hasSpokenInitial) {
      _hasSpokenInitial = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          TTSService.instance.falar(_config.messageText, caller: this);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  _CategoryConfig get _config {
    final isDificuldade = _tipo == 'dificuldade';
    switch (_categoria) {
      case 'medicacao':
        return _CategoryConfig(
          icon: Icons.medication,
          color: AppColors.medicationsColor,
          titleText: 'HORA DO REMÉDIO',
          message: isDificuldade 
              ? 'Tudo bem. Avisei que você precisa de ajuda com o seu remédio.'
              : 'Tudo bem! Vou te lembrar em 10 minutos para tomar seu remédio.',
          tip: isDificuldade
              ? 'Não se preocupe, seu cuidador já foi notificado.'
              : 'Deixe o remédio em um lugar visível para não esquecer.',
          detailedExplanation: isDificuldade
              ? 'Esta tela avisa que você precisa de ajuda com o remédio e eu já avisei quem cuida de você. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.'
              : 'Esta tela avisa que o remédio foi adiado por dez minutos. Eu vou te chamar de novo quando passar esse tempo. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.',
        );
      case 'refeicoes':
        return _CategoryConfig(
          icon: Icons.restaurant,
          color: AppColors.mealsColor,
          titleText: 'HORA DE COMER',
          message: isDificuldade
              ? 'Tudo bem. Avisei que você precisa de ajuda com a sua refeição.'
              : 'Combinado! Em 10 minutos vou te avisar que é hora de fazer a refeição.',
          tip: isDificuldade
              ? 'Não se preocupe, seu cuidador já foi notificado.'
              : 'Comer nos horários certos cuida da sua saúde!',
          detailedExplanation: isDificuldade
              ? 'Esta tela avisa que você precisa de ajuda com a refeição e eu já avisei quem cuida de você. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.'
              : 'Esta tela avisa que a refeição foi adiada por dez minutos. Eu vou te chamar de novo quando passar esse tempo para você comer. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.',
        );
      case 'hidratacao':
        return _CategoryConfig(
          icon: Icons.water_drop,
          color: const Color(0xFF0288D1),
          titleText: 'HORA DE BEBER ÁGUA',
          message: isDificuldade
              ? 'Tudo bem. Avisei que você precisa de ajuda para beber água.'
              : 'Certo! Em 10 minutos vou lembrar você de beber água.',
          tip: isDificuldade
              ? 'Não se preocupe, seu cuidador já foi notificado.'
              : 'Manter-se hidratado é essencial para o seu bem-estar.',
          detailedExplanation: isDificuldade
              ? 'Esta tela avisa que você precisa de ajuda com a água e eu já avisei quem cuida de você. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.'
              : 'Esta tela avisa que a água foi adiada por dez minutos. Eu vou te chamar de novo quando passar esse tempo para você se hidratar. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.',
        );
      case 'exercicio':
        return _CategoryConfig(
          icon: Icons.directions_walk,
          color: const Color(0xFF2E7D32),
          titleText: 'HORA DO EXERCÍCIO',
          message: isDificuldade
              ? 'Tudo bem. Avisei que você precisa de ajuda com o seu exercício.'
              : 'Ok! Em 10 minutos vou te avisar para fazer seu exercício.',
          tip: isDificuldade
              ? 'Não se preocupe, seu cuidador já foi notificado.'
              : 'Movimentar o corpo faz bem para a saúde e o humor!',
          detailedExplanation: isDificuldade
              ? 'Esta tela avisa que você precisa de ajuda com o exercício e eu já avisei quem cuida de você. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.'
              : 'Esta tela avisa que o exercício foi adiado por dez minutos. Eu vou te chamar de novo quando passar esse tempo. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.',
        );
      default:
        return _CategoryConfig(
          icon: Icons.alarm,
          color: AppColors.primary,
          titleText: 'HORA DO LEMBRETE',
          message: isDificuldade
              ? 'Tudo bem. Avisei que você precisa de ajuda com a sua atividade.'
              : 'Tudo bem! Vou te lembrar novamente em 10 minutos.',
          tip: isDificuldade
              ? 'Não se preocupe, seu cuidador já foi notificado.'
              : 'Fique tranquilo, não vou deixar você esquecer.',
          detailedExplanation: isDificuldade
              ? 'Esta tela avisa que você precisa de ajuda com a tarefa e eu já avisei quem cuida de você. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.'
              : 'Esta tela avisa que a tarefa foi adiada por dez minutos. Eu vou te chamar de novo quando passar esse tempo. Agora você pode apertar o botão amarelo de FECHAR APLICATIVO.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        TTSService.instance.parar();
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const VolumeWarningBanner(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildTopBar(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              cfg.titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 2,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            MeExplicaButton(
                              textoExplicacao: cfg.detailedExplanation,
                            ),
                            const SizedBox(height: 24),
                            _buildPulsingIcon(cfg.icon, cfg.color),
                            const SizedBox(height: 32),

                            // STATUS CARD
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cfg.color.withValues(alpha: 0.3), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: cfg.color.withValues(alpha: 0.1),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'STATUS DO LEMBRETE:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _tipo == 'dificuldade' ? 'Ajuda Solicitada' : 'Adiado por 10 Minutos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: cfg.color,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    cfg.tip,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // FECHAR APLICATIVO button
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  TTSService.instance.parar();
                                  SystemNavigator.pop();
                                },
                                icon: const Icon(Icons.exit_to_app, size: 36),
                                label: const Text(
                                  'FECHAR APLICATIVO',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondaryContainer,
                                  foregroundColor: AppColors.onSecondaryContainer,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: const Center(
        child: Text(
          'Lembrete Amigo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon(IconData icon, Color color) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(icon, size: 72, color: color),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                _tipo == 'dificuldade'
                    ? Icons.warning_amber_rounded
                    : Icons.access_time_rounded,
                color: _tipo == 'dificuldade' ? Colors.red : Colors.amber,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryConfig {
  final IconData icon;
  final Color color;
  final String titleText;
  final String message;
  final String tip;
  final String detailedExplanation;

  const _CategoryConfig({
    required this.icon,
    required this.color,
    required this.titleText,
    required this.message,
    required this.tip,
    required this.detailedExplanation,
  });

  String get messageText => message.replaceAll('\n', ' ');
}
