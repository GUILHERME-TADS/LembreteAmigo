import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AudioSendFeedbackConnectedScreen extends StatelessWidget {
  const AudioSendFeedbackConnectedScreen({super.key});

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
                child: const Icon(Icons.cloud_done, size: 64, color: AppColors.onTertiaryFixedVariant),
              ),
              const SizedBox(height: 24),
              const Text(
                'Áudio Sincronizado!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Áudio enviado e sincronizado com todos os dispositivos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixedDim.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, size: 16, color: AppColors.onTertiaryFixedVariant),
                    SizedBox(width: 8),
                    Text('Sincronizado', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant)),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryFixed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('VOLTAR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
