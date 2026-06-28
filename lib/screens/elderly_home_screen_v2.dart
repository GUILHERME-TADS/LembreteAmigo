import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';

class ElderlyHomeScreenV2 extends StatefulWidget {
  const ElderlyHomeScreenV2({super.key});

  @override
  State<ElderlyHomeScreenV2> createState() => _ElderlyHomeScreenV2State();
}

class _ElderlyHomeScreenV2State extends State<ElderlyHomeScreenV2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, João!',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
                            ),
                            Text(
                              'Como você está hoje?',
                              style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications, color: AppColors.onSecondaryContainer, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildNextReminderBanner(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/recording-audio'),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondaryContainer,
                          border: Border.all(color: Colors.white, width: 8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 56,
                              color: AppColors.onSecondaryContainer,
                            ),
                            Text(
                              'Falar',
                              style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w700,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Toque para falar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.primary),
                    ),
                    const SizedBox(height: 32),
                    SeniorCard(
                      icon: const Icon(Icons.medication, size: 40),
                      title: 'Remédios',
                      subtitle: 'Próximo: 08:00',
                      borderColor: AppColors.medicationsColor,
                      iconBgColor: AppColors.medicationsColor,
                      onTap: () => Navigator.pushNamed(context, '/medication-list'),
                    ),
                    const SizedBox(height: 16),
                    SeniorCard(
                      icon: const Icon(Icons.restaurant, size: 40),
                      title: 'Refeições',
                      subtitle: 'Suas refeições do dia',
                      borderColor: AppColors.mealsColor,
                      iconBgColor: AppColors.mealsColor,
                      onTap: () => Navigator.pushNamed(context, '/meals'),
                    ),
                    const SizedBox(height: 16),
                    SeniorCard(
                      icon: const Icon(Icons.directions_walk, size: 40),
                      title: 'Exercício',
                      subtitle: 'Caminhada às 14:30',
                      borderColor: AppColors.tertiaryContainer,
                      iconBgColor: AppColors.tertiaryContainer,
                      onTap: () => Navigator.pushNamed(context, '/exercise'),
                    ),
                    const SizedBox(height: 16),
                    SeniorCard(
                      icon: const Icon(Icons.water_drop, size: 40),
                      title: 'Hidratação',
                      subtitle: 'Beber água ao longo do dia',
                      borderColor: AppColors.voiceFeedbackBlue,
                      iconBgColor: AppColors.voiceFeedbackBlue,
                      onTap: () => Navigator.pushNamed(context, '/water'),
                    ),
                    const SizedBox(height: 16),
                    SeniorCard(
                      icon: const Icon(Icons.notifications, size: 40),
                      title: 'Personalizados',
                      subtitle: 'Seus lembretes avulsos',
                      borderColor: AppColors.customColor,
                      iconBgColor: AppColors.customColor,
                      onTap: () => Navigator.pushNamed(context, '/custom'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          ),
          const Spacer(),
          const Text('Lembrete Amigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {}, // Simulado para demonstração
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/elderly-profile'),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.primaryContainer, width: 2),
                ),
              ),
              child: const Icon(Icons.person, color: AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextReminderBanner() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/medication-list'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 12,
                  color: AppColors.medicationsColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.medicationsColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.medication, color: AppColors.medicationsColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'PRÓXIMO LEMBRETE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: AppColors.medicationsColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Dor de cabeça — 19:00',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
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

  Widget _buildBottomNav() {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Início', true),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/elderly-help'),
            child: _navItem(Icons.help_center, 'Ajuda', false),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.secondaryContainer : null,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
