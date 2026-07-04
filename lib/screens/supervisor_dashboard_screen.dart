import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/smart_alert.dart';
import '../services/health_service.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/smart_alert_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/reminder_with_audio.dart';
import '../widgets/supervisor_bottom_nav.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  int? _lastBpm;
  bool _isLoadingBpm = true;
  StreamSubscription<int>? _bpmSubscription;
  Timer? _smartAlertTimer;
  String _nomeIdoso = 'Idoso';
  List<SmartAlert> _smartAlerts = [];

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
    SmartAlertService.instance.notifier.addListener(_onSmartAlertsChanged);
    _smartAlertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      SmartAlertService.instance.atualizar(
        LembreteService.instance.lembretes,
        bpm: _lastBpm,
      );
    });
    _bpmSubscription = HealthService.instance.obterMetricasStream().listen((
      bpm,
    ) {
      if (mounted) {
        setState(() {
          _lastBpm = bpm;
          _isLoadingBpm = false;
        });
        SmartAlertService.instance.atualizar(
          LembreteService.instance.lembretes,
          bpm: bpm,
        );
      }
    });
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    _smartAlertTimer?.cancel();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    SmartAlertService.instance.notifier.removeListener(_onSmartAlertsChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      bpm: _lastBpm,
    );
    if (mounted) setState(() {});
  }

  void _onSmartAlertsChanged() {
    if (mounted) {
      setState(() {
        _smartAlerts = SmartAlertService.instance.alerts;
      });
    }
  }

  Future<void> _loadBpmAndLembretes() async {
    await LembreteService.instance.carregar();
    await SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      bpm: _lastBpm,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final bpm = prefs.getInt('last_bpm_value');
      final idosoId = await SessionRoleService.getActiveIdosoId();

      String nome = 'Idoso';
      if (_useFirebase) {
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null) {
          nome = doc.data()!['nome'] as String? ?? 'Idoso';
        }
      } else {
        final jsonStr = prefs.getString('idoso_perfil');
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          nome = data['nome'] as String? ?? 'Idoso';
        }
      }

      if (mounted) {
        await SmartAlertService.instance.atualizar(
          LembreteService.instance.lembretes,
          bpm: bpm,
        );
        if (!mounted) return;
        setState(() {
          _lastBpm = bpm;
          _isLoadingBpm = false;
          _nomeIdoso = nome.split(' ').first;
          _smartAlerts = SmartAlertService.instance.alerts;
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
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.home,
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
                    _buildSmartAlertsSection(),
                    if (_smartAlerts.isNotEmpty) const SizedBox(height: 24),
                    _buildMessagesShortcut(),
                    const SizedBox(height: 24),
                    _buildOverviewSection(),
                    const SizedBox(height: 24),
                    _buildHealthSnapshot(),
                    const SizedBox(height: 24),
                    _buildTodayReminders(context),
                    const SizedBox(height: 24),
                    _buildRecentHistory(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
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
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
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

  Widget _buildSmartAlertsSection() {
    if (_smartAlerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text(
              'Alertas Inteligentes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._smartAlerts.take(3).map(_buildSmartAlertCard),
      ],
    );
  }

  Widget _buildMessagesShortcut() {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/messages'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant, width: 2),
          ),
          child: const Row(
            children: [
              Icon(Icons.forum, color: AppColors.primary, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recados',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Leia mensagens de áudio e responda ao idoso.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartAlertCard(SmartAlert alert) {
    final isCritical = alert.severity == SmartAlertSeverity.critical;
    final isWarning = alert.severity == SmartAlertSeverity.warning;
    final icon = isCritical
        ? Icons.priority_high
        : isWarning
        ? Icons.warning_amber
        : Icons.info_outline;
    final foreground = isCritical
        ? AppColors.error
        : isWarning
        ? AppColors.onSecondaryContainer
        : AppColors.primary;
    final background = isCritical
        ? AppColors.errorContainer
        : isWarning
        ? AppColors.secondaryContainer.withValues(alpha: 0.35)
        : AppColors.primaryContainer.withValues(alpha: 0.5);
    final border = isCritical
        ? AppColors.error
        : isWarning
        ? AppColors.secondary
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/activity-history'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: isCritical ? 3 : 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: foreground, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final list = LembreteService.instance.lembretes;
    final totalMedicacoesHoje = list
        .where((l) => l.categoria == 'medicacao')
        .length;
    final concluidasMedicacoesHoje = list
        .where((l) => l.categoria == 'medicacao' && l.concluido)
        .length;

    String statusRemediosText = 'Nenhum remédio agendado para hoje.';
    bool todosTomados = false;
    if (totalMedicacoesHoje > 0) {
      todosTomados = concluidasMedicacoesHoje == totalMedicacoesHoje;
      statusRemediosText = todosTomados
          ? '$_nomeIdoso tomou todos os remédios hoje.'
          : '$_nomeIdoso tomou $concluidasMedicacoesHoje de $totalMedicacoesHoje remédios hoje.';
    }

    final IconData statusIcon = totalMedicacoesHoje == 0
        ? Icons.info_outline
        : (todosTomados ? Icons.check_circle : Icons.warning_amber);
    final Color statusIconColor = totalMedicacoesHoje == 0
        ? AppColors.outline
        : (todosTomados ? AppColors.tertiaryFixedDim : AppColors.secondary);
    final Color statusTextColor = totalMedicacoesHoje == 0
        ? AppColors.onSurfaceVariant
        : (todosTomados
              ? AppColors.onTertiaryContainer
              : AppColors.onSecondaryContainer);

    final agoraTime = TimeOfDay.fromDateTime(DateTime.now());
    Lembrete? proximoLembrete;
    int minDiff = 999999;
    for (final l in list) {
      if (!l.concluido) {
        final diff =
            (l.horarioHour * 60 + l.horarioMinute) -
            (agoraTime.hour * 60 + agoraTime.minute);
        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          proximoLembrete = l;
        }
      }
    }
    if (proximoLembrete == null) {
      final pendentes = list.where((l) => !l.concluido).toList();
      if (pendentes.isNotEmpty) {
        pendentes.sort(
          (a, b) => (a.horarioHour * 60 + a.horarioMinute).compareTo(
            b.horarioHour * 60 + b.horarioMinute,
          ),
        );
        proximoLembrete = pendentes.first;
      }
    }

    final nextTimeText = proximoLembrete != null
        ? proximoLembrete.horarioFormatado
        : '--:--';
    final nextTitleText = proximoLembrete != null
        ? proximoLembrete.titulo
        : 'Sem pendências';

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
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(statusIcon, color: statusIconColor, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusRemediosText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: statusTextColor,
                        ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRÓXIMO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.05,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nextTimeText,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              nextTitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.05,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '--',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                            Text(
                              'Sem dados',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
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
            child: const Icon(
              Icons.favorite,
              size: 32,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ritmo Cardíaco',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bpmText,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          Text(
            'BPM • $statusText',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        AudioPlayerCard(
          accentColor: AppColors.primary,
          subtitle: 'Ouça todos os lembretes do dia',
          textsToSpeak: list.isEmpty
              ? ['Nenhum lembrete cadastrado para hoje.']
              : [
                  'Lembretes de hoje para $_nomeIdoso:',
                  ...list.map((l) => '${l.titulo} às ${l.horarioFormatado}.'),
                ],
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
            child: const Column(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.outline,
                ),
                SizedBox(height: 16),
                Text(
                  'Nenhum lembrete cadastrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
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
            final status = reminderVisualStatusFromLembrete(lembrete);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
    final agora = DateTime.now();
    final ontem = agora.subtract(const Duration(days: 1));
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    final eventosOntem = LembreteService.instance.eventos.where((e) {
      return e.registradoEm.year == ontem.year &&
          e.registradoEm.month == ontem.month &&
          e.registradoEm.day == ontem.day;
    }).toList();

    int totalOntem = eventosOntem
        .where((e) => e.categoria != 'bem_estar')
        .length;
    int concluidosOntem = eventosOntem
        .where((e) => e.categoria != 'bem_estar' && e.status.isConcluido)
        .length;

    DateTime targetDate = ontem;
    List<LembreteEvento> targetEvents = eventosOntem;

    if (targetEvents.isEmpty && LembreteService.instance.eventos.isNotEmpty) {
      final sortedEvents = List<LembreteEvento>.from(
        LembreteService.instance.eventos,
      )..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));

      final nonTodayEvents = sortedEvents.where((e) {
        return !(e.registradoEm.year == agora.year &&
            e.registradoEm.month == agora.month &&
            e.registradoEm.day == agora.day);
      }).toList();

      if (nonTodayEvents.isNotEmpty) {
        final lastEventDate = nonTodayEvents.first.registradoEm;
        targetDate = lastEventDate;
        targetEvents = LembreteService.instance.eventos.where((e) {
          return e.registradoEm.year == lastEventDate.year &&
              e.registradoEm.month == lastEventDate.month &&
              e.registradoEm.day == lastEventDate.day;
        }).toList();

        totalOntem = targetEvents
            .where((e) => e.categoria != 'bem_estar')
            .length;
        concluidosOntem = targetEvents
            .where((e) => e.categoria != 'bem_estar' && e.status.isConcluido)
            .length;
      }
    }

    final totalMedicacoes = targetEvents
        .where((e) => e.categoria == 'medicacao')
        .length;
    final concluidasMedicacoes = targetEvents
        .where((e) => e.categoria == 'medicacao' && e.status.isConcluido)
        .length;
    final totalRefeicoes = targetEvents
        .where((e) => e.categoria == 'refeicoes')
        .length;
    final concluidasRefeicoes = targetEvents
        .where((e) => e.categoria == 'refeicoes' && e.status.isConcluido)
        .length;
    final totalExercicios = targetEvents
        .where((e) => e.categoria == 'exercicio')
        .length;
    final concluidasExercicios = targetEvents
        .where((e) => e.categoria == 'exercicio' && e.status.isConcluido)
        .length;

    final targetIsOntem =
        targetDate.year == ontem.year &&
        targetDate.month == ontem.month &&
        targetDate.day == ontem.day;
    final String dateHeader = targetIsOntem
        ? 'Ontem, ${targetDate.day.toString().padLeft(2, '0')} de ${meses[targetDate.month - 1]}'
        : 'Dia ${targetDate.day.toString().padLeft(2, '0')} de ${meses[targetDate.month - 1]}';

    final int pctConcluido = totalOntem > 0
        ? ((concluidosOntem / totalOntem) * 100).toInt()
        : 100;

    final String medValue = totalMedicacoes > 0
        ? '$concluidasMedicacoes/$totalMedicacoes ok'
        : '--';
    final String refValue = totalRefeicoes > 0
        ? '$concluidasRefeicoes/$totalRefeicoes ok'
        : '--';
    final String exeValue = totalExercicios > 0
        ? '$concluidasExercicios/$totalExercicios ok'
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Histórico Recente',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
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
                    Text(
                      dateHeader,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixedDim,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pctConcluido% Concluído',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onTertiaryFixedVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    _historyMetric(label: 'Medicamentos', value: medValue),
                    const SizedBox(width: 12),
                    _historyMetric(label: 'Refeições', value: refValue),
                    const SizedBox(width: 12),
                    _historyMetric(label: 'Exercícios', value: exeValue),
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
