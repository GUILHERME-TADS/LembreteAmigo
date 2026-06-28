import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Aperte o botão amarelo se você for o idoso, ou o botão branco se você for o supervisor.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
              const Text(
                'Lembrete Amigo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        TTSService.instance.falar(
                          'Aperte o botão amarelo se você for o idoso, ou o botão branco se você for o supervisor.',
                          caller: this,
                        );
                      },
                      child: const AlexAvatar(size: 140),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Olá! Como vamos cuidar hoje?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Escolha o seu perfil para acessar a plataforma personalizada para as suas necessidades.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildProfileButton(
                      icon: Icons.elderly,
                      title: 'Sou o Idoso',
                      subtitle: 'Acesso fácil e simplificado',
                      bgColor: AppColors.secondaryContainer,
                      textColor: AppColors.onSecondaryContainer,
                      iconBgColor: AppColors.surfaceContainerLowest,
                      iconColor: AppColors.onSecondaryContainer,
                      onTap: () async {
                        TTSService.instance.parar(caller: this);
                        final prefs = await SharedPreferences.getInstance();
                        final isPaired = prefs.getString('paired_idoso_id') != null;
                        if (!mounted) return;
                        if (isPaired) {
                          Navigator.pushNamed(context, '/elderly-home', arguments: {'connected': true});
                        } else {
                          Navigator.pushNamed(context, '/elderly-onboarding');
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildProfileButton(
                      icon: Icons.medical_services,
                      title: 'Sou o Supervisor',
                      subtitle: 'Painel de controle e monitoramento',
                      bgColor: AppColors.surfaceContainerLowest,
                      textColor: AppColors.primary,
                      iconBgColor: AppColors.primaryContainer,
                      iconColor: AppColors.onPrimaryContainer,
                      onTap: () {
                        TTSService.instance.parar(caller: this);
                        Navigator.pushNamed(context, '/supervisor-login');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Text(
                      'Precisa de ajuda com o aplicativo?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.support_agent, size: 20),
                          label: const Text('Suporte'),
                        ),
                        const Text('|', style: TextStyle(color: AppColors.outlineVariant)),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.info, size: 20),
                          label: const Text('Sobre'),
                        ),
                      ],
                    ),
                    const Text(
                      'v1.0.2 • Lembrete Amigo',
                      style: TextStyle(fontSize: 10, color: AppColors.outline, letterSpacing: 2),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color textColor,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFD1D1D1),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: textColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 32, color: textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
