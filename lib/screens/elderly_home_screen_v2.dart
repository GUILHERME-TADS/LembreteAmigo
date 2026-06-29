import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';
import '../services/tts_service.dart';

class ElderlyHomeScreenV2 extends StatefulWidget {
  const ElderlyHomeScreenV2({super.key});

  @override
  State<ElderlyHomeScreenV2> createState() => _ElderlyHomeScreenV2State();
}

class _ElderlyHomeScreenV2State extends State<ElderlyHomeScreenV2> {
  String _nome = 'Idoso';

  @override
  void initState() {
    super.initState();
    _loadProfileName();
  }

  Future<void> _loadProfileName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final nomeCompleto = data['nome'] as String? ?? 'Idoso';
        if (mounted) {
          setState(() {
            _nome = nomeCompleto.split(' ').first;
          });
        }
      }
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          TTSService.instance.parar(caller: this);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AlexAssistantSheet(),
          );
        },
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: AlexAvatar(size: 48),
        ),
      ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, $_nome!',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
                            ),
                            const Text(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 100,
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Lembrete Amigo',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  TTSService.instance.parar(caller: this);
                  TTSService.instance.falar(
                    'Esta é a tela de início rápida. Aqui você vê suas notificações e pode falar com o Alex no botão de falar no final da tela.',
                    caller: this,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Me explica',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, 'Início', true, null),
              _navItem(Icons.help_center, 'Ajuda', false, () {
                Navigator.pushNamed(context, '/elderly-help');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected, VoidCallback? onTap) {
    final itemColor = selected 
        ? AppColors.primary 
        : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.05) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: itemColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
