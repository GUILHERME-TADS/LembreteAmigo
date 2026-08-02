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
import '../services/secure_cache_service.dart';
import '../utils/firebase_helper.dart';
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
                                if (FirebaseHelper.isDemoRecording) {
                                  await SessionRoleService.setElderly();
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                    'paired_idoso_id',
                                    'idoso_simulado',
                                  );
                                  await prefs.setBool(
                                    'elderly_autonomous_mode',
                                    false,
                                  );
                                  await LembreteService.instance
                                      .prepareDemoRecordingCache();
                                  if (!context.mounted) return;
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/elderly-home',
                                    (route) => false,
                                    arguments: {'connected': true},
                                  );
                                  return;
                                }
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
                                if (previousId != null &&
                                    previousId != user.uid) {
                                  // Clear old account preferences and profile data
                                  await prefs.remove('idoso_perfil');
                                  await prefs.remove('idoso_foto_path');
                                  await prefs.remove('alex_voice_rate');
                                  await prefs.remove('alex_voice_pitch');
                                  await prefs.remove(
                                    'always_listening_enabled',
                                  );
                                  await prefs.remove('elderly_autonomous_mode');

                                  // Clear local/autonomous reminder and event cache fallbacks
                                  final secureCache =
                                      SecureCacheService.instance;
                                  await secureCache.delete(
                                    'lembretes_idoso_local',
                                  );
                                  await secureCache.delete(
                                    'elderly_backup_lembretes_idoso_local',
                                  );
                                  await secureCache.delete(
                                    'lembretes_eventos_idoso_local',
                                  );
                                  await secureCache.delete(
                                    'offline_write_queue_elderly_anonymous_idoso_local',
                                  );

                                  // Clean up old legacy fallback keys just in case
                                  await secureCache.delete(
                                    'lembretes_idoso_autonomo',
                                  );
                                  await secureCache.delete(
                                    'elderly_backup_lembretes_idoso_autonomo',
                                  );
                                  await secureCache.delete(
                                    'lembretes_idoso_sem_vinculo',
                                  );
                                  await secureCache.delete(
                                    'lembretes_idoso_simulado',
                                  );
                                  await secureCache.delete('lembretes');
                                  await secureCache.delete(
                                    'lembretes_eventos_idoso_autonomo',
                                  );
                                  await secureCache.delete(
                                    'lembretes_eventos_idoso_sem_vinculo',
                                  );
                                  await secureCache.delete(
                                    'lembretes_eventos_idoso_simulado',
                                  );
                                  await secureCache.delete('lembretes_eventos');
                                  await secureCache.delete(
                                    'offline_write_queue_elderly_anonymous_idoso_autonomo',
                                  );
                                  await secureCache.delete(
                                    'offline_write_queue_elderly_anonymous_idoso_sem_vinculo',
                                  );
                                }
                                await prefs.setString(
                                  'paired_idoso_id',
                                  user.uid,
                                );
                                await PushNotificationService.instance
                                    .saveCurrentToken();
                                if (!context.mounted) return;
                                if (previousId == user.uid) {
                                  final isPaired =
                                      await SessionRoleService.isElderlyConnectedToSupervisor();
                                  if (!context.mounted) return;
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/elderly-home',
                                    (route) => false,
                                    arguments: {'connected': isPaired},
                                  );
                                } else {
                                  if (!context.mounted) return;
                                  Navigator.pushNamed(
                                    context,
                                    '/elderly-onboarding',
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                if (!context.mounted) return;
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
                                if (!context.mounted) return;
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
                                if (!context.mounted) return;
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
                                  showInfoBottomSheet(
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
                                  showInfoBottomSheet(
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
    IconData? icon,
    Widget? customIconWidget,
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
                  child: Center(
                    child:
                        customIconWidget ??
                        Icon(icon, size: 32, color: iconColor),
                  ),
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
