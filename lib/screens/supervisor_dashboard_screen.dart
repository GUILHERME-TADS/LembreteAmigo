import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/reminder_with_audio.dart';
import '../services/lembrete_service.dart';
import '../services/health_service.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  int? _lastBpm;
  bool _isLoadingBpm = true;
  StreamSubscription<int>? _bpmSubscription;
  String _nomeIdoso = 'João';

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBpmAndLembretes();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
    _bpmSubscription = HealthService.instance.obterMetricasStream().listen((bpm) {
      if (mounted) {
        setState(() {
          _lastBpm = bpm;
          _isLoadingBpm = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBpmAndLembretes() async {
    await LembreteService.instance.carregar();
    try {
      final prefs = await SharedPreferences.getInstance();
      final bpm = prefs.getInt('last_bpm_value');
      final idosoId = prefs.getString('selected_idoso_id') ?? 'joao';
      
      String nome = 'João';
      if (_useFirebase) {
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null) {
          nome = doc.data()!['nome'] as String? ?? 'João';
        }
      } else {
        final jsonStr = prefs.getString('idoso_perfil');
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          nome = data['nome'] as String? ?? 'João';
        }
      }
      
      if (mounted) {
        setState(() {
          _lastBpm = bpm;
          _isLoadingBpm = false;
          _nomeIdoso = nome.split(' ').first;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBpm = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/new-reminder'),
        backgroundColor: AppColors.secondaryContainer,
        foregroundColor: AppColors.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 36),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildOverviewSection(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/elderly-profile'),
                      child: _buildHealthSnapshot(),
                    ),
                    const SizedBox(height: 24),
                    _buildTodayReminders(context),
                    const SizedBox(height: 24),
                    _buildRecentHistory(context),
                    const SizedBox(height: 120),
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
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/supervisor-settings'),
            child: const Icon(Icons.settings, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Text('Lembrete Amigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/emergency-alert'),
            child: const Icon(Icons.warning_amber, color: AppColors.error),
          ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(24),
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
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.tertiaryFixedDim, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_nomeIdoso tomou todos os remédios hoje.',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 1.5, color: AppColors.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRÓXIMO',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '14:30',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                            Text(
                              'Caminhada Diária',
                              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BATERIA',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '85%',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.secondary),
                            ),
                            Text(
                              'Dispositivo Ativo',
                              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthSnapshot() {
    final bpmText = _isLoadingBpm 
        ? '--' 
        : (_lastBpm != null ? '$_lastBpm' : '72');
    final statusText = _isLoadingBpm 
        ? 'CARREGANDO' 
        : (_lastBpm != null ? 'LIDO DA CÂMERA' : 'ESTÁVEL');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, size: 32, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ritmo Cardíaco',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(height: 8),
          Text(
            bpmText,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.onPrimaryContainer),
          ),
          Text(
            'BPM • $statusText',
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayReminders(BuildContext context) {
    final list = LembreteService.instance.lembretes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lembretes de Hoje',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        const SizedBox(height: 16),
        const AudioPlayerCard(
          accentColor: AppColors.primary,
          subtitle: 'Ouça todos os lembretes do dia',
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant, width: 2),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.outline,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum lembrete cadastrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adicione lembretes de remédios, refeições ou exercícios clicando no botão + abaixo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...list.map((lembrete) {
            IconData icon = Icons.notifications;
            Color iconBg = AppColors.customColor.withValues(alpha: 0.2);
            Color iconColor = AppColors.customColor;
            Color accentColor = AppColors.customColor;
            String categoryLabel = 'Personalizado';

            switch (lembrete.categoria) {
              case 'medicacao':
                icon = Icons.medical_services;
                iconBg = AppColors.secondaryContainer;
                iconColor = AppColors.onSecondaryContainer;
                accentColor = AppColors.medicationsColor;
                categoryLabel = 'Medicamento';
                break;
              case 'refeicoes':
                icon = Icons.restaurant;
                iconBg = AppColors.mealsColor.withValues(alpha: 0.2);
                iconColor = AppColors.mealsColor;
                accentColor = AppColors.mealsColor;
                categoryLabel = 'Refeição';
                break;
              case 'exercicio':
                icon = Icons.directions_walk;
                iconBg = AppColors.tertiaryContainer.withValues(alpha: 0.2);
                iconColor = AppColors.onTertiaryContainer;
                accentColor = AppColors.tertiaryContainer;
                categoryLabel = 'Exercício';
                break;
              case 'hidratacao':
                icon = Icons.water_drop;
                iconBg = AppColors.voiceFeedbackBlue.withValues(alpha: 0.2);
                iconColor = AppColors.voiceFeedbackBlue;
                accentColor = AppColors.voiceFeedbackBlue;
                categoryLabel = 'Água';
                break;
            }

            final status = lembrete.concluido 
                ? ReminderStatus.done 
                : ReminderStatus.scheduled;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ReminderWithAudio(
                icon: icon,
                iconBg: iconBg,
                iconColor: iconColor,
                title: lembrete.titulo,
                time: lembrete.horarioFormatado,
                status: status,
                accentColor: accentColor,
                audioPath: lembrete.audioPath,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/supervisor-reminder-detail',
                    arguments: {
                      'title': lembrete.titulo,
                      'time': lembrete.horarioFormatado,
                      'iconData': icon,
                      'accentColor': accentColor,
                      'category': categoryLabel,
                    },
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Histórico Recente',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/detailed-history'),
              child: const Text('VER RELATÓRIOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05)),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ontem, 03 de Outubro',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixedDim,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '95% Concluído',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    _historyMetric(label: 'Refeições', value: '3/3 ok'),
                    const SizedBox(width: 12),
                    _historyMetric(label: 'Medicamentos', value: '5/5 ok'),
                    const SizedBox(width: 12),
                    _historyMetric(label: 'Sono', value: '7h 20m'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyMetric({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                  color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
