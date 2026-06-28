import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      _buildIconSection(),
                      const SizedBox(height: 48),
                      const Text(
                        'Opa, o sinal fugiu!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Parece que a internet deu uma voltinha. Vamos tentar trazer ela de volta?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildWifiTip(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
            _buildRetryButton(context),
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
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Lembrete Amigo',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Icon(Icons.refresh, color: AppColors.primary, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant, width: 4),
          ),
        ),
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 100, color: AppColors.error),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 4),
            ),
            child: const Icon(Icons.signal_wifi_connected_no_internet_4, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildWifiTip() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_find, color: AppColors.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Verifique se o seu Wi-Fi está ligado ou se o celular tem sinal.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface.withValues(alpha: 0),
            AppColors.surface,
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.replay, size: 32),
          label: const Text(
            'TENTAR DE NOVO',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
