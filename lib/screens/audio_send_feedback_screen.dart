import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AudioSendFeedbackScreen extends StatelessWidget {
  const AudioSendFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const Spacer(),
              Container(
                width: 120,
                height: 120,
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
              const SizedBox(height: 24),
              const Text(
                'Áudio Enviado!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Seu áudio foi enviado com sucesso. O idoso poderá ouvir a mensagem personalizada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'O lembrete será disparado no horário configurado.',
                        style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/supervisor-dashboard', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryFixed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('VOLTAR AO PAINEL', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
