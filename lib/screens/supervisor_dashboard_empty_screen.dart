import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SupervisorDashboardEmptyScreen extends StatelessWidget {
  const SupervisorDashboardEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_today, size: 64, color: AppColors.onSurfaceVariant),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none, size: 20, color: AppColors.onSecondaryContainer),
                          ),
                        ),
                        Positioned(
                          bottom: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.task_alt, size: 20, color: AppColors.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Ainda não há lembretes para o João',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Organize a rotina de cuidados de forma simples e eficiente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/new-reminder'),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'CRIAR PRIMEIRO LEMBRETE',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryFixed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                        children: [
                          Icon(Icons.info_outline, size: 20, color: AppColors.onSurfaceVariant),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Os lembretes ajudam a garantir que nada seja esquecido na rotina de cuidados.',
                              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/register-elderly'),
            child: const Icon(Icons.person_add, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Text(
            'Cuidador',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/supervisor-settings'),
            child: const Icon(Icons.settings, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        children: [
          _bottomNavItem(Icons.home, 'Início', true, null),
          _bottomNavItem(Icons.notifications, 'Lembretes', false, () {}),
          _bottomNavItem(Icons.favorite, 'Saúde', false, () {}),
          _bottomNavItem(Icons.person, 'Perfil', false, () {}),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool selected, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
              Text(label.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
