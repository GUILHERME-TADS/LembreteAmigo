import 'dart:async';
import 'dart:convert';



import '../utils/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/device_barrier.dart';
import '../models/device_diagnostics.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/smart_alert.dart';
import '../services/device_barrier_service.dart';
import '../services/supervisor_ai_service.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/smart_alert_service.dart';
import '../services/message_service.dart';
import '../services/video_call_service.dart';
import '../services/effectiveness_service.dart';
import '../utils/period_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/message_unread_badge.dart';
import '../widgets/reminder_with_audio.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';
import 'photo_gallery_screen.dart';
import '../widgets/charts/adherence_trend_chart.dart';
import '../widgets/charts/category_distribution_chart.dart';
import '../widgets/charts/weekly_comparison_chart.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  StreamSubscription<DeviceDiagnostics>? _deviceBarrierSubscription;
  Timer? _smartAlertTimer;
  String _nomeIdoso = 'Idoso';
  String _enderecoIdoso = '';
  String _selectedCategoryFilter = 'Todos';
  String _selectedStatusFilter = 'Todos';
  String _dateFilterMode = 'hoje'; // 'hoje', 'data', 'todos'
  DateTime _selectedDate = DateTime.now();
  bool _showChartsAccordion = false;
  bool _refortIsLoading = false;
  bool _callIsLoading = false;
  SupervisorInsights? _aiInsights;
  bool _aiLoading = false;
  bool _aiLoaded = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<SmartAlert> _smartAlerts = [];
  Map<DateTime, double> _dailyAdherence = {};
  int _currentWeekCompleted = 0;
  int _currentWeekTotal = 0;
  int _previousWeekCompleted = 0;
  int _previousWeekTotal = 0;
  List<DeviceBarrier> _deviceBarriers = [];
  int? _batteryLevel;
  String? _batteryState;
  bool _isConnected = false;
  bool _checkingConnection = true;
  bool _deviceDiagnosticsStale = false;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  Future<void> _checkSupervisorConnection() async {
    final connected = await SessionRoleService.isSupervisorConnected();
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _checkConnectionAndInit() async {
    if (mounted) {
      setState(() {
        _checkingConnection = true;
      });
    }
    try {
      await _checkSupervisorConnection();
      if (_isConnected) {
        await _loadLembretesAndProfile();
        unawaited(_startDeviceBarrierWatcher());
        LembreteService.instance.notifier.removeListener(_onLembretesChanged);
        LembreteService.instance.notifier.addListener(_onLembretesChanged);
        LembreteService.instance.eventosNotifier.removeListener(
          _onEventosChanged,
        );
        LembreteService.instance.eventosNotifier.addListener(_onEventosChanged);
        SmartAlertService.instance.notifier.removeListener(
          _onSmartAlertsChanged,
        );
        SmartAlertService.instance.notifier.addListener(_onSmartAlertsChanged);
        _smartAlertTimer?.cancel();
        _smartAlertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          SmartAlertService.instance.atualizar(
            LembreteService.instance.lembretes,
            eventos: LembreteService.instance.eventos,
          );
        });
      } else {
        await _deviceBarrierSubscription?.cancel();
        _deviceBarrierSubscription = null;
        _smartAlertTimer?.cancel();
        LembreteService.instance.notifier.removeListener(_onLembretesChanged);
        LembreteService.instance.eventosNotifier.removeListener(
          _onEventosChanged,
        );
        SmartAlertService.instance.notifier.removeListener(
          _onSmartAlertsChanged,
        );
      }
    } catch (error) {
      debugPrint('Erro ao iniciar painel do cuidador: $error');
    } finally {
      if (mounted) {
        setState(() => _checkingConnection = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkConnectionAndInit();
  }

  @override
  void dispose() {
    _deviceBarrierSubscription?.cancel();
    _smartAlertTimer?.cancel();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    LembreteService.instance.eventosNotifier.removeListener(_onEventosChanged);
    SmartAlertService.instance.notifier.removeListener(_onSmartAlertsChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      eventos: LembreteService.instance.eventos,
    );
    _computeChartData();
    if (mounted) setState(() {});
  }

  void _onEventosChanged() {
    SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      eventos: LembreteService.instance.eventos,
    );
    _computeChartData();
    if (mounted) setState(() {});
  }

  void _onSmartAlertsChanged() {
    if (mounted) {
      setState(() {
        _smartAlerts = SmartAlertService.instance.alerts;
      });
    }
  }

  void _computeChartData() {
    final now = DateTime.now();
    final eventos = EffectivenessService.instance.collapseOccurrences(
      LembreteService.instance.eventos,
    );

    _dailyAdherence = {};
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final dayEvents = eventos.where(
        (e) => !e.registradoEm.isBefore(day) && !e.registradoEm.isAfter(dayEnd),
      );
      final total = dayEvents.length;
      if (total == 0) {
        _dailyAdherence[day] = -1;
      } else {
        final completed = dayEvents.where((e) => e.status.isConcluido).length;
        _dailyAdherence[day] = (completed / total * 100);
      }
    }

    final weekStart = DateTime(now.year, now.month, now.day - 6);
    final twoWeeksAgo = DateTime(now.year, now.month, now.day - 13);

    final currentWeekEvents = eventos.where(
      (e) =>
          !e.registradoEm.isBefore(weekStart) &&
          !e.registradoEm.isAfter(now) &&
          e.categoria != 'bem_estar',
    );
    _currentWeekTotal = currentWeekEvents.length;
    _currentWeekCompleted = currentWeekEvents
        .where((e) => e.status.isConcluido)
        .length;

    final previousWeekEvents = eventos.where(
      (e) =>
          !e.registradoEm.isBefore(twoWeeksAgo) &&
          e.registradoEm.isBefore(weekStart) &&
          e.categoria != 'bem_estar',
    );
    _previousWeekTotal = previousWeekEvents.length;
    _previousWeekCompleted = previousWeekEvents
        .where((e) => e.status.isConcluido)
        .length;
  }

  Future<void> _startDeviceBarrierWatcher() async {
    if (!_isConnected) return;
    final idosoId = await SessionRoleService.getActiveIdosoId();
    await _deviceBarrierSubscription?.cancel();

    if (!_useFirebase) {
      final diagnostics = await DeviceBarrierService.instance
          .loadLocalDiagnostics();
      if (!mounted) return;
      setState(() {
        _deviceBarriers = diagnostics.barriers;
        _batteryLevel = diagnostics.batteryLevel;
        _batteryState = diagnostics.batteryState;
        _deviceDiagnosticsStale = false;
      });
      return;
    }

    _deviceBarrierSubscription = DeviceBarrierService.instance
        .watchRemoteDiagnostics(idosoId)
        .listen(
          (diagnostics) {
            if (!mounted) return;
            setState(() {
              _deviceBarriers = diagnostics.barriers;
              _batteryLevel = diagnostics.batteryLevel;
              _batteryState = diagnostics.batteryState;
              _deviceDiagnosticsStale = false;
            });
          },
          onError: (error) {
            debugPrint('Diagnóstico remoto indisponível: $error');
            if (!mounted) return;
            setState(() => _deviceDiagnosticsStale = true);
          },
        );
  }

  Future<void> _loadLembretesAndProfile() async {
    if (!_isConnected) return;
    await LembreteService.instance.carregar();
    await SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      eventos: LembreteService.instance.eventos,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();

      String nome = 'Idoso';
      String endereco = '';
      var localProfile = <String, dynamic>{};
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          localProfile = data;
          nome = data['nome'] as String? ?? nome;
          endereco = data['endereco'] as String? ?? endereco;
        } catch (error) {
          debugPrint('Perfil local inválido no painel: $error');
        }
      }
      if (_useFirebase) {
        try {
          final data = await ElderlyProfileRepository.instance
              .getMergedData(idosoId)
              .timeout(const Duration(seconds: 6));
          nome = data['nome'] as String? ?? nome;
          endereco = data['endereco'] as String? ?? endereco;
          await prefs.setString(
            'idoso_perfil',
            jsonEncode({...localProfile, 'nome': nome, 'endereco': endereco}),
          );
        } catch (error) {
          debugPrint('Usando perfil local no painel: $error');
        }
      }

      if (mounted) {
        await SmartAlertService.instance.atualizar(
          LembreteService.instance.lembretes,
          eventos: LembreteService.instance.eventos,
        );
        _computeChartData();
        if (!mounted) return;
        setState(() {
          _nomeIdoso = nome.split(' ').first;
          _enderecoIdoso = endereco;
          _smartAlerts = SmartAlertService.instance.alerts;
        });
      }
      _loadAIInsights();
    } catch (_) {}
  }

  Future<void> _loadAIInsights() async {
    if (_aiLoaded || _aiLoading) return;
    setState(() => _aiLoading = true);
    final insights = await SupervisorAIService.instance.getDailySummary();
    if (mounted) {
      setState(() {
        _aiInsights = insights;
        _aiLoading = false;
        _aiLoaded = true;
      });
    }
  }

  Future<void> _initiateCall(String callType) async {
    if (_callIsLoading) return;
    if (!_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum idoso conectado.')),
        );
      }
      return;
    }
    setState(() => _callIsLoading = true);
    try {
      final idosoId = await SessionRoleService.getActiveIdosoId();
      final callStart = await VideoCallService.instance.initiateCall(
        idosoId: idosoId,
        callType: callType,
      );
      if (callStart == null && mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        final reason = VideoCallService.instance.lastStartFailureMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason ?? 'Erro ao iniciar chamada de $label.'),
          ),
        );
        return;
      }
      if (mounted && callStart != null) {
        await VideoCallService.instance.joinCall(
          callStart.roomName,
          callType: callType,
          callId: callStart.callId,
          alreadyVerified: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar chamada de $label: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _callIsLoading = false);
    }
  }

  Future<void> _enviarReforco(BuildContext context, Lembrete lembrete) async {
    if (_refortIsLoading) return;
    setState(() => _refortIsLoading = true);
    try {
      final periodo = PeriodHelper.getPeriodLabel(lembrete.horarioHour).toUpperCase();
      final horaStr =
          '${lembrete.horarioHour.toString().padLeft(2, '0')}:${lembrete.horarioMinute.toString().padLeft(2, '0')} DA $periodo';
      final sent = await MessageService.instance.sendText(
        'ATENÇÃO ${_nomeIdoso.toUpperCase()}: SEU LEMBRETE ${lembrete.titulo.toUpperCase()} ESTÁ MARCADO PARA $horaStr, NÃO SE ESQUEÇA',
      );
      if (!sent) {
        throw StateError('Nenhum idoso conectado para receber o reforço.');
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reforço enviado como mensagem para o idoso.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar o reforço: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _refortIsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingConnection) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoading(height: 24, width: 160),
                const SizedBox(height: 24),
                SkeletonCard(lines: 2, lineHeight: 20),
                const SizedBox(height: 16),
                SkeletonCard(lines: 4, lineHeight: 16),
                const SizedBox(height: 16),
                SkeletonLoading(height: 200),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/supervisor-dashboard'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.home,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _isConnected
                  ? RefreshIndicator(
                      onRefresh: _refreshDashboard,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          children: [
                            _buildQuickActionsBar(),
                            const SizedBox(height: 20),
                            _buildAISummarySection(),
                            const SizedBox(height: 24),
                            _buildSmartAlertsSection(),
                            if (_smartAlerts.isNotEmpty)
                              const SizedBox(height: 24),
                            _buildDeviceBarrierSection(),
                            if (_deviceBarriers.isNotEmpty)
                              const SizedBox(height: 24),
                            _buildMessagesShortcut(),
                            const SizedBox(height: 24),
                            _buildOverviewSection(),
                            const SizedBox(height: 24),
                            _buildExpandableChartsSection(),
                            const SizedBox(height: 24),
                            _buildTodayReminders(context),
                            const SizedBox(height: 24),
                            _buildRecentHistory(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    )
                  : _buildUnconnectedState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnconnectedState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_off,
                  size: 80,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dispositivo Não Vinculado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para receber e visualizar as informações em tempo real (lembretes e alertas), você precisa conectar o seu painel ao dispositivo do idoso utilizando o código de 6 dígitos gerado no aplicativo dele.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/register-elderly');
                    _checkConnectionAndInit();
                  },
                  icon: const Icon(Icons.link, size: 28),
                  label: const Text(
                    'CONECTAR APARELHO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final lembretes = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
    final alertasCriticos =
        lembretes.where((l) {
          final status = reminderVisualStatusFromLembrete(l);
          return status == ReminderStatus.late ||
              status == ReminderStatus.missed ||
              status == ReminderStatus.needsHelp;
        }).toList()..sort((a, b) {
          int prioridade(Lembrete lembrete) {
            switch (reminderVisualStatusFromLembrete(lembrete)) {
              case ReminderStatus.needsHelp:
                return 0;
              case ReminderStatus.missed:
                return 1;
              case ReminderStatus.late:
                return 2;
              default:
                return 3;
            }
          }

          return prioridade(a).compareTo(prioridade(b));
        });
    final temAlerta = _isConnected && alertasCriticos.isNotEmpty;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: AppColors.primary, size: 32),
          ),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              if (temAlerta) {
                Navigator.pushNamed(
                  context,
                  '/emergency-alert',
                  arguments: {
                    'lembrete': alertasCriticos.first,
                    'totalAlertas': alertasCriticos.length,
                  },
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nenhum alerta crítico ativo no momento.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: temAlerta
                    ? AppColors.errorContainer
                    : AppColors.outlineVariant.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber,
                color: temAlerta
                    ? AppColors.error
                    : AppColors.outline.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummarySection() {
    if (_aiLoading) {
      return Card(
        color: AppColors.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Gerando resumo inteligente...',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiInsights == null || !_aiInsights!.hasContent) {
      return const SizedBox.shrink();
    }

    final insights = _aiInsights!;
    return Card(
      color: AppColors.primaryFixed.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'RESUMO INTELIGENTE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insights.summary,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (insights.insights.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...insights.insights.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimaryFixedVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(i, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (insights.attentionPoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'ATENCAO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              ...insights.attentionPoints.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (insights.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'SUGESTOES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimaryFixedVariant,
                  letterSpacing: 1,
                ),
              ),
              ...insights.suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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

  Widget _buildDeviceBarrierSection() {
    if (_deviceBarriers.isEmpty) return const SizedBox.shrink();

    final criticalCount = _deviceBarriers
        .where((b) => b.severity == DeviceBarrierSeverity.critical)
        .length;
    final warningCount = _deviceBarriers
        .where((b) => b.severity == DeviceBarrierSeverity.warning)
        .length;
    final infoCount = _deviceBarriers
        .where((b) => b.severity == DeviceBarrierSeverity.info)
        .length;
    final isCritical = criticalCount > 0;
    final foreground = isCritical
        ? AppColors.error
        : AppColors.onSecondaryContainer;
    final background = isCritical
        ? AppColors.errorContainer
        : AppColors.secondaryContainer.withValues(alpha: 0.35);
    final summary = criticalCount > 0
        ? '$criticalCount critica${criticalCount == 1 ? '' : 's'}'
        : warningCount > 0
        ? '$warningCount atencao${warningCount == 1 ? '' : 'es'}'
        : '$infoCount aviso${infoCount == 1 ? '' : 's'}';

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: foreground, width: isCritical ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: foreground.withValues(alpha: isCritical ? 0.3 : 0.15),
              blurRadius: isCritical ? 12 : 6,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_antenna, color: foreground, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Radar do Celular - $summary',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _startDeviceBarrierWatcher(),
                  icon: Icon(Icons.refresh, color: foreground, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._deviceBarriers.take(3).map(_buildDeviceBarrierRow),
            if (_deviceDiagnosticsStale) ...[
              const SizedBox(height: 10),
              const Text(
                'Exibindo o último diagnóstico recebido.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            if (_enderecoIdoso.isNotEmpty) ...[
              const Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_enderecoIdoso)}';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ver endereço do idoso no mapa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceBarrierRow(DeviceBarrier barrier) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _deviceBarrierIcon(barrier.type),
            color: AppColors.onSurface,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barrier.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  barrier.message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _deviceBarrierIcon(DeviceBarrierType type) {
    switch (type) {
      case DeviceBarrierType.lowVolume:
        return Icons.volume_down;
      case DeviceBarrierType.offline:
        return Icons.wifi_off;
      case DeviceBarrierType.pendingSync:
        return Icons.sync_problem;
      case DeviceBarrierType.inactiveApp:
        return Icons.phone_android;
      case DeviceBarrierType.locationUnavailable:
        return Icons.location_off;
    }
  }

  Widget _buildMessagesShortcut() {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/messages'),
              child: Row(
                children: [
                  const MessageUnreadBadge(
                    child: Icon(
                      Icons.forum,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recados Rápidos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Grave e envie recados de voz para o idoso.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 24, color: AppColors.outlineVariant),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/messages'),
                icon: const Icon(Icons.mic, color: Colors.white),
                label: const Text(
                  'Gravar recado de voz',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
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
              boxShadow: [
                BoxShadow(
                  color: border.withValues(alpha: isCritical ? 0.35 : 0.15),
                  blurRadius: isCritical ? 10 : 5,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
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
    final list = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
    final totalMedicacoesHoje = list
        .where((l) => l.categoria == 'medicacao')
        .length;
    final concluidasMedicacoesHoje = list
        .where((l) => l.categoria == 'medicacao' && l.concluido)
        .length;

    String statusRemediosText = 'Nenhum remédio agendado para hoje.';
    bool todosTomados = false;
    double percent = 0.0;
    if (totalMedicacoesHoje > 0) {
      todosTomados = concluidasMedicacoesHoje == totalMedicacoesHoje;
      percent = concluidasMedicacoesHoje / totalMedicacoesHoje;
      statusRemediosText = todosTomados
          ? '$_nomeIdoso tomou todos os remédios hoje.'
          : '$_nomeIdoso tomou $concluidasMedicacoesHoje de $totalMedicacoesHoje remédios hoje.';
    }

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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Visão Geral',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.onSurface,
                      ),
                    ),

                    GestureDetector(
                      onTap: _callIsLoading
                          ? null
                          : () => _initiateCall('voice'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_in_talk,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Áudio',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _callIsLoading
                          ? null
                          : () => _initiateCall('video'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Vídeo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: totalMedicacoesHoje > 0 ? percent : 1.0,
                            strokeWidth: 8,
                            backgroundColor: AppColors.surfaceContainer,
                            color: totalMedicacoesHoje == 0
                                ? AppColors.outline
                                : (todosTomados
                                      ? Colors.green
                                      : AppColors.secondaryContainer),
                          ),
                        ),
                        Text(
                          totalMedicacoesHoje > 0
                              ? '${(percent * 100).toInt()}%'
                              : '0%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todosTomados
                                ? 'Tudo em dia!'
                                : 'Pendências de hoje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: todosTomados
                                  ? Colors.green
                                  : AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusRemediosText,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nextTimeText,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              nextTitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BATERIA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _batteryLevel != null ? '$_batteryLevel%' : '--',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color:
                                    _batteryLevel != null &&
                                        _batteryLevel! <= 15
                                    ? AppColors.error
                                    : (_batteryState == 'charging'
                                          ? Colors.green
                                          : AppColors.secondary),
                              ),
                            ),
                            Text(
                              _batteryLevel == null
                                  ? 'Sem dados'
                                  : (_batteryState == 'charging'
                                        ? 'Carregando'
                                        : _batteryState == 'full'
                                        ? 'Carregada'
                                        : 'Descarregando'),
                              style: const TextStyle(
                                fontSize: 12,
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

  Widget _buildCategoryFilters() {
    final Map<String, String> categories = {
      'Todos': 'Todos',
      'medicacao': 'Medicação',
      'refeicoes': 'Refeições',
      'exercicio': 'Exercício',
      'hidratacao': 'Hidratação',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.entries.map((entry) {
          final isSelected = _selectedCategoryFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceContainer,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategoryFilter = entry.key;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    HapticFeedback.mediumImpact();
    await _checkConnectionAndInit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do painel atualizados!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Ações Rápidas no Idoso',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _callIsLoading ? null : () => _initiateCall('video'),
                  icon: const Icon(Icons.videocam, size: 20),
                  label: const Text('Chamada de Vídeo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/supervisor-messages'),
                  icon: const Icon(Icons.mic, size: 20),
                  label: const Text('Recado de Voz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/new-reminder'),
                  icon: const Icon(Icons.add_alarm, size: 20),
                  label: const Text('Novo Lembrete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB8C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _refreshDashboard,
                  icon: const Icon(Icons.sync, size: 20),
                  label: const Text('Sincronizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableChartsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _showChartsAccordion = !_showChartsAccordion;
              });
            },
            leading: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 28),
            title: const Text(
              'Análises e Gráficos Detalhados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            subtitle: Text(
              _showChartsAccordion ? 'Toque para recolher os gráficos' : 'Toque para ver adesão, comparação e categorias',
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            trailing: Icon(
              _showChartsAccordion ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          if (_showChartsAccordion) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildAdherenceChartSection(),
                  const SizedBox(height: 24),
                  _buildWeeklyComparisonSection(),
                  const SizedBox(height: 24),
                  _buildCategoryChartSection(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilters(List<Lembrete> allReminders) {
    int countAtrasados = 0;
    int countPendentes = 0;
    int countConcluidos = 0;
    for (final l in allReminders) {
      final st = reminderVisualStatusFromLembrete(l);
      if (st == ReminderStatus.late || st == ReminderStatus.missed || st == ReminderStatus.needsHelp) {
        countAtrasados++;
      } else if (st == ReminderStatus.scheduled || st == ReminderStatus.postponed) {
        countPendentes++;
      } else if (st == ReminderStatus.done || st == ReminderStatus.doneWithPhoto || st == ReminderStatus.caregiverConfirmed) {
        countConcluidos++;
      }
    }

    final filters = [
      {'key': 'Todos', 'label': '⚪ Todos (${allReminders.length})'},
      {'key': 'Atrasados', 'label': '🔴 Atrasados ($countAtrasados)'},
      {'key': 'Pendentes', 'label': '🟡 Pendentes ($countPendentes)'},
      {'key': 'Concluídos', 'label': '🟢 Tomados ($countConcluidos)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final isSelected = _selectedStatusFilter == item['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                item['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: item['key'] == 'Atrasados'
                  ? AppColors.error
                  : item['key'] == 'Pendentes'
                      ? const Color(0xFFF59E0B)
                      : item['key'] == 'Concluídos'
                          ? Colors.green
                          : AppColors.primary,
              backgroundColor: AppColors.surfaceContainerLowest,
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = selected ? item['key']! : 'Todos';
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateFilterMode = 'data';
      });
    }
  }

  Widget _buildDateModeChip(String label, String mode, IconData icon) {
    final isSelected = _dateFilterMode == mode;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : AppColors.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      showCheckmark: false,
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceContainer,
      onSelected: (selected) {
        if (selected) {
          if (mode == 'data' && _dateFilterMode != 'data') {
            _pickDate();
          } else if (mode == 'data' && _dateFilterMode == 'data') {
            _pickDate();
          } else {
            setState(() {
              _dateFilterMode = mode;
            });
          }
        }
      },
    );
  }

  Widget _buildTodayReminders(BuildContext context) {
    final targetDate = _dateFilterMode == 'hoje' ? DateTime.now() : _selectedDate;
    
    var rawList = _dateFilterMode == 'todos'
        ? LembreteService.instance.lembretes.toList()
        : ReminderStateHelper.activeTodaySorted(
            LembreteService.instance.lembretes,
            now: targetDate,
          );

    if (_dateFilterMode == 'todos') {
      rawList.sort((a, b) {
        if (a.horarioHour != b.horarioHour) {
          return a.horarioHour.compareTo(b.horarioHour);
        }
        return a.horarioMinute.compareTo(b.horarioMinute);
      });
    }

    var filteredList = _selectedCategoryFilter == 'Todos'
        ? rawList
        : rawList.where((l) => l.categoria == _selectedCategoryFilter).toList();

    if (_selectedStatusFilter == 'Atrasados') {
      filteredList = filteredList.where((l) {
        final st = reminderVisualStatusFromLembrete(l);
        return st == ReminderStatus.late || st == ReminderStatus.missed || st == ReminderStatus.needsHelp;
      }).toList();
    } else if (_selectedStatusFilter == 'Pendentes') {
      filteredList = filteredList.where((l) {
        final st = reminderVisualStatusFromLembrete(l);
        return st == ReminderStatus.scheduled || st == ReminderStatus.postponed;
      }).toList();
    } else if (_selectedStatusFilter == 'Concluídos') {
      filteredList = filteredList.where((l) {
        final st = reminderVisualStatusFromLembrete(l);
        return st == ReminderStatus.done || st == ReminderStatus.doneWithPhoto || st == ReminderStatus.caregiverConfirmed;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lembretes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDateModeChip('Hoje', 'hoje', Icons.today),
              const SizedBox(width: 8),
              _buildDateModeChip(
                _dateFilterMode == 'data' 
                  ? 'Dia ${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}' 
                  : 'Outra Data', 
                'data', 
                Icons.calendar_month,
              ),
              const SizedBox(width: 8),
              _buildDateModeChip('Todos', 'todos', Icons.all_inclusive),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryFilters(),
        const SizedBox(height: 8),
        _buildStatusFilters(rawList),

        if (filteredList.isEmpty)
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
                  'Nenhum lembrete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Adicione lembretes clicando no botão + abaixo.',
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
          ...filteredList.map((lembrete) {
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
                categoryLabel = 'Medicação';
                break;
              case 'refeicoes':
                icon = Icons.restaurant;
                iconBg = AppColors.mealsColor.withValues(alpha: 0.2);
                iconColor = AppColors.mealsColor;
                accentColor = AppColors.mealsColor;
                categoryLabel = 'Refeições';
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
                categoryLabel = 'Hidratação';
                break;
            }
            final status = reminderVisualStatusFromLembrete(lembrete);
            final bool isPending =
                status == ReminderStatus.scheduled ||
                status == ReminderStatus.late;
            final bool needsAttention =
                status == ReminderStatus.late ||
                status == ReminderStatus.missed ||
                status == ReminderStatus.needsHelp;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.transparent, // Borda oculta para não duplicar com a borda vermelha interna do ReminderWithAudio
                    width: needsAttention ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    ReminderWithAudio(
                      icon: icon,
                      iconBg: iconBg,
                      iconColor: iconColor,
                      title: lembrete.titulo,
                      time: lembrete.horarioFormatado,
                      status: status,
                      accentColor: accentColor,
                      audioPath: lembrete.audioPath == 'ia_generated'
                          ? null
                          : lembrete.audioPath,
                      ttsText: lembrete.audioPath == 'ia_generated'
                          ? lembrete.medicamentoAudioTexto
                          : null,
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
                            'lembrete': lembrete,
                          },
                        );
                      },
                    ),
                    if (isPending) ...[
                      const Divider(height: 1, color: AppColors.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                status == ReminderStatus.late
                                    ? 'Atrasado há mais de 5 min!'
                                    : 'Agendado',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: status == ReminderStatus.late
                                      ? AppColors.error
                                      : AppColors.outline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton.icon(
                                onPressed: _refortIsLoading
                                    ? null
                                    : () => _enviarReforco(context, lembrete),
                                icon: _refortIsLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primary,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.volume_up, size: 16),
                                label: const Text(
                                  'Enviar reforço',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentHistory(BuildContext context) {
    final agora = DateTime.now();
    final ontem = agora.subtract(const Duration(days: 1));
    final allEvents = EffectivenessService.instance.collapseOccurrences(
      LembreteService.instance.eventos,
    );
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

    final eventosOntem = allEvents.where((e) {
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

    if (targetEvents.isEmpty && allEvents.isNotEmpty) {
      final sortedEvents = List<LembreteEvento>.from(allEvents)
        ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));

      final nonTodayEvents = sortedEvents.where((e) {
        return !(e.registradoEm.year == agora.year &&
            e.registradoEm.month == agora.month &&
            e.registradoEm.day == agora.day);
      }).toList();

      if (nonTodayEvents.isNotEmpty) {
        final lastEventDate = nonTodayEvents.first.registradoEm;
        targetDate = lastEventDate;
        targetEvents = allEvents.where((e) {
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

    final String completionText = totalOntem > 0
        ? '${((concluidosOntem / totalOntem) * 100).toInt()}% concluído'
        : 'Sem dados';

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
        const Text(
          'Histórico Recente',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
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
                    Expanded(
                      child: Text(
                        dateHeader,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        completionText,
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
              // Gallery button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhotoGalleryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text(
                      'Ver Galeria de Fotos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
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

  Widget _buildAdherenceChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Tendência de Adesão',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Últimos 14 dias',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AdherenceTrendChart(dailyAdherence: _dailyAdherence),
        ],
      ),
    );
  }

  Widget _buildWeeklyComparisonSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Comparativo Semanal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeeklyComparisonChart(
            currentWeekCompleted: _currentWeekCompleted,
            currentWeekTotal: _currentWeekTotal,
            previousWeekCompleted: _previousWeekCompleted,
            previousWeekTotal: _previousWeekTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartSection() {
    final lembretes = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
    final completedByCategory = <String, int>{};
    final totalByCategory = <String, int>{};

    for (final l in lembretes) {
      final cat = l.categoria;
      totalByCategory[cat] = (totalByCategory[cat] ?? 0) + 1;
      if (l.concluido) {
        completedByCategory[cat] = (completedByCategory[cat] ?? 0) + 1;
      }
    }

    if (totalByCategory.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Distribuição por Categoria',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CategoryDistributionChart(
            completedByCategory: completedByCategory,
            totalByCategory: totalByCategory,
          ),
        ],
      ),
    );
  }
}
