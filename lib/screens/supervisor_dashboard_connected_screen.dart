import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/reminder_with_audio.dart';

class SupervisorDashboardConnectedScreen extends StatelessWidget {
  const SupervisorDashboardConnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildOverview(),
                    const SizedBox(height: 16),
                    _buildHealthSnapshot(),
                    const SizedBox(height: 24),
                    const Text(
                      'Lembretes de Hoje',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                    const AudioPlayerCard(
                      accentColor: AppColors.primary,
                      subtitle: 'Ouça todos os lembretes do dia',
                    ),
                    const SizedBox(height: 16),
                    ReminderWithAudio(
                      icon: Icons.medical_services,
                      iconBg: AppColors.secondaryContainer,
                      iconColor: AppColors.onSecondaryContainer,
                      title: 'Remédio da Pressão',
                      time: '08:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.medicationsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Remédio da Pressão', 'time': '08:00', 'iconData': Icons.medical_services, 'accentColor': AppColors.medicationsColor, 'category': 'Medicamento'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.free_breakfast,
                      iconBg: AppColors.mealsColor,
                      iconColor: Colors.white,
                      title: 'Café da manhã',
                      time: '08:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.mealsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Café da manhã', 'time': '08:00', 'iconData': Icons.free_breakfast, 'accentColor': AppColors.mealsColor, 'category': 'Refeição'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.directions_walk,
                      iconBg: AppColors.tertiaryContainer,
                      iconColor: Colors.white,
                      title: 'Caminhada matinal',
                      time: '09:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.tertiaryContainer,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Caminhada matinal', 'time': '09:00', 'iconData': Icons.directions_walk, 'accentColor': AppColors.tertiaryContainer, 'category': 'Exercício'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.accessibility_new,
                      iconBg: AppColors.tertiaryContainer,
                      iconColor: Colors.white,
                      title: 'Alongamento',
                      time: '10:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.tertiaryContainer,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Alongamento', 'time': '10:00', 'iconData': Icons.accessibility_new, 'accentColor': AppColors.tertiaryContainer, 'category': 'Exercício'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.medication,
                      iconBg: AppColors.tertiaryFixed,
                      iconColor: AppColors.onTertiaryFixed,
                      title: 'Vitamina',
                      time: '12:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.medicationsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Vitamina', 'time': '12:00', 'iconData': Icons.medication, 'accentColor': AppColors.medicationsColor, 'category': 'Medicamento'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.restaurant,
                      iconBg: AppColors.mealsColor,
                      iconColor: Colors.white,
                      title: 'Almoço',
                      time: '12:00',
                      status: ReminderStatus.done,
                      accentColor: AppColors.mealsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Almoço', 'time': '12:00', 'iconData': Icons.restaurant, 'accentColor': AppColors.mealsColor, 'category': 'Refeição'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.directions_walk,
                      iconBg: AppColors.tertiaryContainer,
                      iconColor: Colors.white,
                      title: 'Caminhada tarde',
                      time: '14:30',
                      accentColor: AppColors.tertiaryContainer,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Caminhada tarde', 'time': '14:30', 'iconData': Icons.directions_walk, 'accentColor': AppColors.tertiaryContainer, 'category': 'Exercício'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.restaurant_menu,
                      iconBg: AppColors.mealsColor,
                      iconColor: Colors.white,
                      title: 'Lanche da tarde',
                      time: '15:00',
                      accentColor: AppColors.mealsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Lanche da tarde', 'time': '15:00', 'iconData': Icons.restaurant_menu, 'accentColor': AppColors.mealsColor, 'category': 'Refeição'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.self_improvement,
                      iconBg: AppColors.tertiaryContainer,
                      iconColor: Colors.white,
                      title: 'Relaxamento',
                      time: '18:00',
                      accentColor: AppColors.tertiaryContainer,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Relaxamento', 'time': '18:00', 'iconData': Icons.self_improvement, 'accentColor': AppColors.tertiaryContainer, 'category': 'Exercício'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.restaurant,
                      iconBg: AppColors.mealsColor,
                      iconColor: Colors.white,
                      title: 'Jantar',
                      time: '19:00',
                      accentColor: AppColors.mealsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Jantar', 'time': '19:00', 'iconData': Icons.restaurant, 'accentColor': AppColors.mealsColor, 'category': 'Refeição'}),
                    ),
                    const SizedBox(height: 12),
                    ReminderWithAudio(
                      icon: Icons.medication,
                      iconBg: AppColors.medicationsColor,
                      iconColor: Colors.white,
                      title: 'Dor de cabeça',
                      time: '19:00',
                      accentColor: AppColors.medicationsColor,
                      onTap: () => Navigator.pushNamed(context, '/supervisor-reminder-detail', arguments: {'title': 'Dor de cabeça', 'time': '19:00', 'iconData': Icons.medication, 'accentColor': AppColors.medicationsColor, 'category': 'Medicamento'}),
                    ),
                    const SizedBox(height: 24),
                    _buildRecentHistory(),
                    const SizedBox(height: 100),
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
            onTap: () => Navigator.pushNamed(context, '/connected-settings'),
            child: const Icon(Icons.settings, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Text('Lembrete Amigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const Spacer(),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.outlineVariant)),
            child: const Icon(Icons.person, size: 24, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visão Geral',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('O idoso tomou todos os\nremédios hoje.', style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixedDim.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 16, color: AppColors.onTertiaryFixedVariant),
                          SizedBox(width: 4),
                          Text('Próximo: 14:30', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text('85%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Container(
                    width: 80, height: 8,
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(9999)),
                    child: const FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.85,
                      child: SizedBox(
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixedDim,
                            borderRadius: BorderRadius.all(Radius.circular(9999)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('BATERIA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSnapshot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: AppColors.error, size: 32),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ritmo Cardíaco', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
              Text('72 BPM', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Histórico Recente', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 16),
          const Row(
            children: [
              Text('Ontem, 03 Out', style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant)),
              Spacer(),
              Text('95%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onTertiaryContainer)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _historyItem('Refeições', '3/3'),
              const SizedBox(width: 16),
              _historyItem('Medicamentos', '5/5'),
              const SizedBox(width: 16),
              _historyItem('Sono', '7h20'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
          ],
        ),
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
          _bottomNavItem(Icons.history, 'Histórico', false, () => Navigator.pushNamed(context, '/detailed-history')),
          _bottomNavItem(Icons.help_center, 'Ajuda', false, () => Navigator.pushNamed(context, '/supervisor-help')),
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
