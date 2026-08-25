import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/reminder_completion_result.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class MedicationConfirmationScreen extends StatefulWidget {
  const MedicationConfirmationScreen({super.key});

  @override
  State<MedicationConfirmationScreen> createState() =>
      _MedicationConfirmationScreenState();
}

class _MedicationConfirmationScreenState
    extends State<MedicationConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  String? _message;
  String? _reminderId;
  DateTime? _registeredAt;
  bool _duplicate = false;
  bool _undoing = false;
  int _undoSeconds = 0;
  Timer? _undoTimer;
  bool _hasSpokenInitial = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _message = args['message'] as String?;
      _reminderId = args['reminderId'] as String?;
      _registeredAt = DateTime.tryParse(args['registeredAt'] as String? ?? '');
      _duplicate = args['duplicate'] == true;
      _startUndoWindow();
    } else if (args is String) {
      _message = args;
    }

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
    _undoTimer?.cancel();
    _controller.dispose();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _startUndoWindow() {
    if (_undoTimer != null || _reminderId == null || _registeredAt == null) {
      return;
    }
    void refresh() {
      final elapsed = DateTime.now().difference(_registeredAt!).inSeconds;
      if (!mounted) return;
      setState(() => _undoSeconds = (30 - elapsed).clamp(0, 30));
      if (_undoSeconds == 0) _undoTimer?.cancel();
    }

    refresh();
    if (_undoSeconds > 0) {
      _undoTimer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }

  Future<void> _undoConfirmation() async {
    final reminderId = _reminderId;
    if (reminderId == null || _undoing || _undoSeconds == 0) return;
    setState(() => _undoing = true);
    final result = await LembreteService.instance.desfazerConfirmacao(
      reminderId,
    );
    if (!mounted) return;
    setState(() => _undoing = false);
    if (result.outcome == ReminderCompletionOutcome.undone) {
      _undoTimer?.cancel();
      await TTSService.instance.falar(
        'Tudo bem. A confirmacao foi desfeita.',
        caller: this,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/active-reminder',
        (route) => false,
        arguments: reminderId,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
    );
  }

  _ConfirmationConfig get _config {
    final msg = (_message ?? 'Você tomou seu remédio.').toLowerCase();

    if (msg.contains('remédio') ||
        msg.contains('medicamento') ||
        msg.contains('medicação')) {
      return _ConfirmationConfig(
        icon: Icons.medication,
        color: AppColors.medicationsColor,
        titleText: 'HORA DO REMÉDIO',
        statusText: 'Remédio Tomado',
        tip: 'Parabéns por cuidar da sua saúde!',
        detailedExplanation:
            'Muito bem! Você tomou o seu remédio. Parabéns por cuidar da sua saúde! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('água') ||
        msg.contains('hidratar') ||
        msg.contains('hidratação') ||
        msg.contains('hidratacao')) {
      return _ConfirmationConfig(
        icon: Icons.water_drop,
        color: AppColors.info,
        titleText: 'HORA DA HIDRATAÇÃO',
        statusText: 'Água Bebida',
        tip: 'Parabéns por beber água!',
        detailedExplanation:
            'Muito bem! Você bebeu a sua água. Parabéns por cuidar do seu corpo! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('refeição') ||
        msg.contains('comer') ||
        msg.contains('comida') ||
        msg.contains('almoço') ||
        msg.contains('jantar')) {
      return _ConfirmationConfig(
        icon: Icons.restaurant,
        color: AppColors.mealsColor,
        titleText: 'HORA DA REFEIÇÃO',
        statusText: 'Você Comeu',
        tip: 'Comer nos horários certos cuida do seu corpo!',
        detailedExplanation:
            'Muito bem! Você comeu. Parabéns por cuidar do seu corpo! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else if (msg.contains('exercício') ||
        msg.contains('atividade') ||
        msg.contains('caminhada') ||
        msg.contains('alongamento')) {
      return _ConfirmationConfig(
        icon: Icons.directions_walk,
        color: AppColors.success,
        titleText: 'HORA DO EXERCÍCIO',
        statusText: 'Exercício Feito',
        tip: 'Movimentar o corpo faz bem para o coração e mente!',
        detailedExplanation:
            'Muito bem! Você fez seu exercício. Parabéns por movimentar seu corpo! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
      );
    } else {
      return _ConfirmationConfig(
        icon: Icons.check_circle_outline,
        color: AppColors.primary,
        titleText: 'LEMBRETE CONCLUÍDO',
        statusText: 'Lembrete concluído',
        tip: 'Parabéns por fazer sua atividade!',
        detailedExplanation:
            'Muito bem! Você concluiu seu lembrete. Parabéns! Agora, aperte no botão amarelo abaixo para voltar à tela inicial.',
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/elderly-home',
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: AlexFloatingHelpButton(
          textoExplicacao: cfg.detailedExplanation,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.successContainer, AppColors.successContainer],
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
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: 2,
                                  color: AppColors.onSurfaceVariant,
                                ),
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
                                  border: Border.all(
                                    color: cfg.color.withValues(alpha: 0.3),
                                    width: 3,
                                  ),
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
                                    Text(
                                      'O QUE ACONTECEU:',
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
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              if (_duplicate)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Esta atividade ja estava confirmada. Nenhum registro ou estoque foi duplicado.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                              if (_reminderId != null && _undoSeconds > 0) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: OutlinedButton.icon(
                                    onPressed: _undoing
                                        ? null
                                        : _undoConfirmation,
                                    icon: _undoing
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Icon(Icons.undo, size: 30),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _undoing
                                            ? 'DESFAZENDO...'
                                            : 'DESFAZER ($_undoSeconds s)',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // VOLTAR PARA O INÍCIO button
                              SizedBox(
                                width: double.infinity,
                                height: 80,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    TTSService.instance.parar();
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/elderly-home',
                                      (route) => false,
                                    );
                                  },
                                  icon: const Icon(Icons.home, size: 36),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'VOLTAR PARA O INÍCIO',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.secondaryContainer,
                                    foregroundColor:
                                        AppColors.onSecondaryContainer,
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
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Center(
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
              child: Icon(Icons.check_circle, color: color, size: 22),
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
