import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/push_notification_service.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../services/message_service.dart';
import '../services/google_auth_service.dart';
import '../widgets/index.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isProcessingTap = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Aperte o botão amarelo se você for o idoso. Aperte o botão branco se você ajuda o idoso.',
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
      floatingActionButton: !SessionRoleService.isSupervisor
          ? const AlexFloatingHelpButton(
              textoExplicacao:
                  'Olá! Esta é a tela para começar. Aperte o botão amarelo se você for o idoso. Aperte o botão branco se você ajuda o idoso.',
            )
          : null,
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
                                'Aperte o botão amarelo se você for o idoso. Aperte o botão branco se você ajuda o idoso.',
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
                          if (!SessionRoleService.isSupervisor) ...[
                            const SizedBox(height: 32),
                          ] else ...[
                            const SizedBox(height: 20),
                          ],
                          _buildProfileButton(
                            icon: Icons.elderly,
                            title: 'Sou o Idoso',
                            subtitle: 'Acesso fácil e simplificado',
                            bgColor: AppColors.secondaryContainer,
                            textColor: AppColors.onSecondaryFixed,
                            iconBgColor: AppColors.surfaceContainerLowest,
                            iconColor: AppColors.onSecondaryFixed,
                            onTap: () async {
                              if (_isProcessingTap) return;
                              setState(() => _isProcessingTap = true);
                              try {
                                TTSService.instance.parar(caller: this);
                                await LembreteService.instance.reset();
                                await MessageService.instance.reset();
                                final credential = await GoogleAuthService
                                    .instance
                                    .signIn();
                                final user = credential.user;
                                if (user == null) {
                                  throw StateError(
                                    'O Google nao retornou uma conta valida.',
                                  );
                                }
                                await SessionRoleService.setElderly();
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final previousId = prefs.getString(
                                  'paired_idoso_id',
                                );
                                await prefs.setString(
                                  'paired_idoso_id',
                                  user.uid,
                                );
                                await PushNotificationService.instance
                                    .saveCurrentToken();
                                if (!mounted) return;
                                if (previousId == user.uid) {
                                  final isPaired =
                                      await SessionRoleService.isElderlyConnectedToSupervisor();
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/elderly-home',
                                    (route) => false,
                                    arguments: {'connected': isPaired},
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    '/elderly-onboarding',
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.code == 'popup-closed-by-user' ||
                                              e.code == 'canceled'
                                          ? 'Login Google cancelado.'
                                          : 'Nao foi possivel entrar com Google: ${e.message ?? e.code}',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Nao foi possivel entrar com Google: $e',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessingTap = false);
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildProfileButton(
                            icon: Icons.medical_services,
                            title: 'Sou o Cuidador',
                            subtitle: 'Painel de controle e monitoramento',
                            bgColor: AppColors.surfaceContainerLowest,
                            textColor: AppColors.primary,
                            iconBgColor: AppColors.primaryContainer,
                            iconColor: AppColors.onPrimaryContainer,
                            onTap: () async {
                              if (_isProcessingTap) return;
                              setState(() => _isProcessingTap = true);
                              try {
                                TTSService.instance.parar(caller: this);
                                await LembreteService.instance.reset();
                                await MessageService.instance.reset();
                                await SessionRoleService.setSupervisor();
                                if (!mounted) return;
                                Navigator.pushNamed(
                                  context,
                                  '/supervisor-login',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessingTap = false);
                                }
                              }
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
                                onPressed: () {
                                  _showInfoBottomSheet(
                                    context: context,
                                    title: 'Suporte',
                                    content:
                                        'Precisa de ajuda com o aplicativo? Nossa equipe está pronta para ajudar!\n\nEmail: suporte@lembreteamigo.com\nTelefone: (11) 99999-8888\n\nHorário de atendimento: Segunda a Sexta, das 8h às 18h.',
                                    icon: Icons.support_agent,
                                  );
                                },
                                icon: const Icon(Icons.support_agent, size: 20),
                                label: const Text('Suporte'),
                              ),
                              const Text(
                                '|',
                                style: TextStyle(
                                  color: AppColors.outlineVariant,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  _showInfoBottomSheet(
                                    context: context,
                                    title: 'Sobre o Lembrete Amigo',
                                    content:
                                        'O Lembrete Amigo é um aplicativo inteligente e de alta acessibilidade projetado para auxiliar idosos na manutenção de suas rotinas de medicação, hidratação e bem-estar, com acompanhamento em tempo real por cuidadores autorizados.\n\nDesenvolvido com carinho para promover independência e tranquilidade para toda a família.',
                                    icon: Icons.info_outline,
                                  );
                                },
                                icon: const Icon(Icons.info, size: 20),
                                label: const Text('Sobre'),
                              ),
                            ],
                          ),
                          const Text(
                            'v1.0.0 • Lembrete Amigo',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.outline,
                              letterSpacing: 2,
                            ),
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
      constraints: const BoxConstraints(minHeight: 120),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  void _showInfoBottomSheet({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(icon, color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'FECHAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
