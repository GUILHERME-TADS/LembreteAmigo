import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConnectedSettingsScreen extends StatelessWidget {
  const ConnectedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                  const Expanded(
                    child: Text(
                      'Configurações',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixedDim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi, size: 16, color: AppColors.onTertiaryFixedVariant),
                        SizedBox(width: 4),
                        Text('Online', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant)),
                      ],
                    ),
                  ),
                ],
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
                    Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_done, size: 40, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                    const Text('Sincronizado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const Text('Última sincronização: há 2 minutos', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _switchTile(Icons.sync, 'Sincronização Automática', true),
              _switchTile(Icons.notifications, 'Notificações Push', true),
              _switchTile(Icons.cloud_upload, 'Upload de Áudio via Wi-Fi', true),
              _switchTile(Icons.storage, 'Modo de Economia de Dados', false),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, bool value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface)),
          ),
          Switch(
            value: value,
            onChanged: (_) {},
            activeThumbColor: AppColors.secondaryContainer,
          ),
        ],
      ),
    );
  }
}
