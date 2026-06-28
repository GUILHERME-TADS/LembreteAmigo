import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../utils/period_helper.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Lembrete? _lembrete;
  bool _hasSpoken = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSpoken) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Lembrete) {
        _lembrete = args;
      }
      _speak();
    }
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _speak() {
    _hasSpoken = true;
    if (_lembrete != null) {
      final timeStr = PeriodHelper.getSpokenTime(_lembrete!.horarioHour, _lembrete!.horarioMinute);
      TTSService.instance.falar(
        'Hora de se mexer. ${_lembrete!.titulo} agendado para às $timeStr. Vamos nos movimentar.',
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        'Hora de se exercitar. Vamos nos movimentar!',
        caller: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _lembrete?.titulo ?? 'HORA DO EXERCÍCIO';
    final subtitle = _lembrete != null 
        ? 'Atividade física agendada para às ${_lembrete!.horarioFormatado}. Vamos lá!'
        : 'Vamos nos movimentar!';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildPulsingIcon(),
                    const SizedBox(height: 32),
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_lembrete != null) {
                            await LembreteService.instance.concluir(_lembrete!.id);
                          }
                          TTSService.instance.parar(caller: this);
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle, size: 32),
                        label: const Text(
                          'ENTENDI',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tertiaryContainer,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_lembrete != null) {
                            await LembreteService.instance.adiar(_lembrete!.id, 10);
                          }
                          TTSService.instance.parar(caller: this);
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.access_time, size: 24),
                        label: const Text(
                          'ADIAR (10 MINUTOS)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildSpeakerIndicator(),
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
            icon: const Icon(Icons.arrow_back, color: AppColors.tertiaryContainer, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Vamos nos Mexer',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.tertiaryContainer),
          ),
          const Spacer(),
          const Icon(Icons.volume_up, color: AppColors.tertiaryContainer, size: 28),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            child: Row(
              children: List.generate(4, (i) => Container(
                width: 4,
                height: [16, 24, 12, 20][i].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
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
          width: 180, height: 180,
          decoration: BoxDecoration(
            color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.tertiaryContainer, width: 4),
          ),
          child: const Icon(Icons.directions_walk, size: 72, color: AppColors.tertiaryContainer),
        ),
      ],
    );
  }

  Widget _buildSpeakerIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hearing, size: 16, color: AppColors.tertiaryContainer),
                SizedBox(width: 8),
                Text(
                  'ALTO-FALANTE ATIVO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.tertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
