import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class MedicationConfirmationScreen extends StatefulWidget {
  const MedicationConfirmationScreen({super.key});

  @override
  State<MedicationConfirmationScreen> createState() => _MedicationConfirmationScreenState();
}

class _MedicationConfirmationScreenState extends State<MedicationConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  String? _message;
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
    _message = ModalRoute.of(context)?.settings.arguments as String?;

    if (!_hasSpokenInitial) {
      _hasSpokenInitial = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          TTSService.instance.falar(_config.detailedExplanation, caller: this);
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

  _ConfirmationConfig get _config {
    final msg = (_message ?? 'Você tomou seu remédio.').toLowerCase();

    if (msg.contains('remédio') ||
        msg.contains('medicamento') ||
        msg.contains('medicação')) {
      return const _ConfirmationConfig(
        icon: Icons.medication,
        color: AppColors.medicationsColor,
        titleText: 'HORA DO REMÉDIO',
        statusText: 'Remédio Tomado',
        tip: 'Parabéns por seguir seu tratamento!',
        detailedExplanation: 'Muito bem! Você tomou o seu remédio. Parabéns por cuidar da sua saúde! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('água') ||
        msg.contains('hidratar') ||
        msg.contains('hidratação') ||
        msg.contains('hidratacao')) {
      return const _ConfirmationConfig(
        icon: Icons.water_drop,
        color: Color(0xFF0288D1),
        titleText: 'HORA DE BEBER ÁGUA',
        statusText: 'Água Bebida',
        tip: 'Parabéns por se manter hidratado!',
        detailedExplanation: 'Muito bem! Você bebeu a sua água. Parabéns por se manter hidratado! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('refeição') ||
        msg.contains('comer') ||
        msg.contains('comida') ||
        msg.contains('almoço') ||
        msg.contains('jantar')) {
      return const _ConfirmationConfig(
        icon: Icons.restaurant,
        color: AppColors.mealsColor,
        titleText: 'HORA DE COMER',
        statusText: 'Refeição Feita',
        tip: 'Comer nos horários certos cuida do seu corpo!',
        detailedExplanation: 'Muito bem! Você fez a sua refeição. Parabéns por se alimentar direitinho! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('exercício') ||
        msg.contains('atividade') ||
        msg.contains('caminhada') ||
        msg.contains('alongamento')) {
      return const _ConfirmationConfig(
        icon: Icons.directions_walk,
        color: Color(0xFF2E7D32),
        titleText: 'HORA DO EXERCÍCIO',
        statusText: 'Atividade Concluída',
        tip: 'Movimentar o corpo faz bem para o coração e mente!',
        detailedExplanation: 'Muito bem! Você concluiu a sua atividade física. Parabéns por movimentar seu corpo! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else {
      return const _ConfirmationConfig(
        icon: Icons.check_circle_outline,
        color: AppColors.primary,
        titleText: 'LEMBRETE CONCLUÍDO',
        statusText: 'Tarefa Concluída',
        tip: 'Parabéns por concluir sua atividade!',
        detailedExplanation: 'Muito bem! Você concluiu a sua tarefa com sucesso. Parabéns! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
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
        Navigator.pushNamedAndRemoveUntil(context, '/elderly-home', (route) => false);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
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
                                      cfg.statusText,
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

                              const SizedBox(height: 24),

                              // VOLTAR PARA O INÍCIO button
                              SizedBox(
                                width: double.infinity,
                                height: 80,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    TTSService.instance.parar();
                                    Navigator.pushNamedAndRemoveUntil(context, '/elderly-home', (route) => false);
                                  },
                                  icon: const Icon(Icons.home, size: 36),
                                  label: const Text(
                                    'VOLTAR PARA O INÍCIO',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.transparent,
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
                Icons.check_circle,
                color: color,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationConfig {
  final IconData icon;
  final Color color;
  final String titleText;
  final String statusText;
  final String tip;
  final String detailedExplanation;

  const _ConfirmationConfig({
    required this.icon,
    required this.color,
    required this.titleText,
    required this.statusText,
    required this.tip,
    required this.detailedExplanation,
  });
}
