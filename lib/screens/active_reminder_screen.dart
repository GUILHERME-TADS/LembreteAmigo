import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class ActiveReminderScreen extends StatelessWidget {
  const ActiveReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    Lembrete? lembrete;
    if (args is Lembrete) {
      lembrete = args;
    } else if (args is String) {
      try {
        lembrete = LembreteService.instance.lembretes.firstWhere((l) => l.id == args);
      } catch (_) {}
    }

    final String titleText;
    final String subtitleText;
    final IconData categoryIcon;
    final Color iconColor;
    final bool requiresPhoto;

    if (lembrete != null) {
      requiresPhoto = lembrete.categoria == 'medicacao';
      categoryIcon = lembrete.categoria == 'medicacao'
          ? Icons.medication
          : lembrete.categoria == 'refeicoes'
              ? Icons.restaurant
              : lembrete.categoria == 'hidratacao'
                  ? Icons.water_drop
                  : lembrete.categoria == 'exercicio'
                      ? Icons.directions_walk
                      : Icons.notifications;
      
      iconColor = lembrete.categoria == 'medicacao'
          ? AppColors.medicationsColor
          : lembrete.categoria == 'refeicoes'
              ? AppColors.mealsColor
              : lembrete.categoria == 'hidratacao'
                  ? AppColors.voiceFeedbackBlue
                  : lembrete.categoria == 'exercicio'
                      ? AppColors.tertiaryContainer
                      : AppColors.primary;

      if (lembrete.categoria == 'medicacao') {
        titleText = 'HORA DO REMÉDIO';
        subtitleText = 'Por favor, tome seu remédio agora.';
      } else if (lembrete.categoria == 'refeicoes') {
        titleText = 'HORA DE COMER';
        subtitleText = 'Por favor, faça sua refeição agora.';
      } else if (lembrete.categoria == 'hidratacao') {
        titleText = 'HORA DE BEBER ÁGUA';
        subtitleText = 'Por favor, beba um copo de água agora.';
      } else if (lembrete.categoria == 'exercicio') {
        titleText = 'HORA DO EXERCÍCIO';
        subtitleText = 'Por favor, faça sua atividade física agora.';
      } else {
        titleText = 'HORA DO LEMBRETE';
        subtitleText = 'Por favor, faça esta atividade agora.';
      }
    } else {
      requiresPhoto = true;
      categoryIcon = Icons.medication;
      iconColor = AppColors.primary;
      titleText = 'HORA DO REMÉDIO';
      subtitleText = 'Por favor, tome seu remédio agora.';
    }

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
                    _buildPulsingMedication(categoryIcon, iconColor),
                    const SizedBox(height: 32),
                    Text(
                      titleText,
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
                      subtitleText,
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
                          TTSService.instance.parar();
                          final navigator = Navigator.of(context);
                          if (requiresPhoto) {
                            navigator.pushNamed(
                              '/take-photo-confirmation',
                              arguments: lembrete?.id,
                            );
                          } else {
                            if (lembrete != null) {
                              await LembreteService.instance.alternarConclusao(lembrete.id);
                            }
                            final feedbackMsg = lembrete?.categoria == 'hidratacao'
                                ? 'Você bebeu sua água.'
                                : lembrete?.categoria == 'refeicoes'
                                    ? 'Você fez sua refeição.'
                                    : lembrete?.categoria == 'exercicio'
                                        ? 'Você fez seu exercício.'
                                        : 'Você concluiu sua atividade.';
                            navigator.pushNamedAndRemoveUntil(
                              '/medication-confirmation',
                              (route) => false,
                              arguments: feedbackMsg,
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 32),
                        label: const Text(
                          'ENTENDI',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tertiaryContainer,
                          foregroundColor: AppColors.onTertiary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          TTSService.instance.parar();
                          Navigator.pushNamed(context, '/medication-reinforcement');
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
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
            onPressed: () {
              TTSService.instance.parar();
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Text(
            'Lembrete Amigo',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              TTSService.instance.parar();
              TTSService.instance.falar(
                'Este é o seu lembrete. Aperte o botão de entendi, ou o botão de adiar.',
              );
            },
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            child: Row(
              children: List.generate(4, (i) => Container(
                width: 4,
                height: [16, 24, 12, 20][i].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingMedication(IconData icon, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Icon(icon, size: 72, color: Colors.white),
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
                Icon(Icons.hearing, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'ALTO-FALANTE ATIVO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

