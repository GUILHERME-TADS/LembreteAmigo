import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';

class ReminderWithAudioScreen extends StatelessWidget {
  const ReminderWithAudioScreen({super.key});

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

    final String titleText = lembrete?.titulo ?? 'Hora de Caminhar';
    final String subtitleText = lembrete != null 
        ? 'Agendado para às ${lembrete.horarioFormatado}'
        : 'Passeio leve na praça - 20 minutos';
    final bool requiresPhoto = lembrete == null || lembrete.categoria == 'medicacao';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Lembrete Amigo',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Mensagem do seu cuidador',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up, size: 48, color: AppColors.onSecondaryContainer),
                    SizedBox(height: 8),
                    Text(
                      'TOCAR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, color: AppColors.primary, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Toque para ouvir a mensagem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () async {
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
                    'CONCLUÍDO',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiaryContainer,
                    foregroundColor: AppColors.onTertiaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

