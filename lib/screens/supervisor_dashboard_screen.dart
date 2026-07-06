import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/device_barrier.dart';
import '../models/device_diagnostics.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../models/smart_alert.dart';
import '../services/device_barrier_service.dart';
import '../services/health_service.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/smart_alert_service.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/reminder_with_audio.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';
import 'photo_gallery_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  int? _lastBpm;
  bool _isLoadingBpm = true;
  StreamSubscription<int?>? _bpmSubscription;
  StreamSubscription<DeviceDiagnostics>? _deviceBarrierSubscription;
  Timer? _smartAlertTimer;
  String _nomeIdoso = 'Idoso';
  String _telefoneIdoso = '';
  String _enderecoIdoso = '';
  String _selectedCategoryFilter = 'Todos';
  final TextEditingController _quickMessageController = TextEditingController();
  bool _sendingQuickMessage = false;
  bool _refortIsLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<SmartAlert> _smartAlerts = [];
  List<DeviceBarrier> _deviceBarriers = [];
  int? _batteryLevel;
  String? _batteryState;
  bool _isConnected = false;
  bool _checkingConnection = true;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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
    await _checkSupervisorConnection();
    if (_isConnected) {
      await _loadBpmAndLembretes();
      _startDeviceBarrierWatcher();
      LembreteService.instance.notifier.removeListener(_onLembretesChanged);
      LembreteService.instance.notifier.addListener(_onLembretesChanged);
      SmartAlertService.instance.notifier.removeListener(_onSmartAlertsChanged);
      SmartAlertService.instance.notifier.addListener(_onSmartAlertsChanged);
      _smartAlertTimer?.cancel();
      _smartAlertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        SmartAlertService.instance.atualizar(
          LembreteService.instance.lembretes,
          eventos: LembreteService.instance.eventos,
          bpm: _lastBpm,
        );
      });
      await _bpmSubscription?.cancel();
      _bpmSubscription = HealthService.instance.obterMetricasStream().listen(
        (bpm) {
          if (mounted) {
            setState(() {
              _lastBpm = bpm;
              _isLoadingBpm = false;
            });
            SmartAlertService.instance.atualizar(
              LembreteService.instance.lembretes,
              eventos: LembreteService.instance.eventos,
              bpm: bpm,
            );
          }
        },
        onError: (error) {
          debugPrint('Erro ao escutar BPM no Firestore: $error');
          if (mounted) {
            setState(() => _isLoadingBpm = false);
          }
        },
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoadingBpm = false;
        });
      }
    }
    if (mounted) {
      setState(() {
        _checkingConnection = false;
      });
    }
  }



  @override
  void initState() {
    super.initState();
    _checkConnectionAndInit();
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    _deviceBarrierSubscription?.cancel();
    _smartAlertTimer?.cancel();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    SmartAlertService.instance.notifier.removeListener(_onSmartAlertsChanged);
    _quickMessageController.dispose();
    super.dispose();
  }

  void _onLembretesChanged() {
    SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      eventos: LembreteService.instance.eventos,
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

  Future<void> _startDeviceBarrierWatcher() async {
    if (!_isConnected) return;
    final idosoId = await SessionRoleService.getActiveIdosoId();
    await _deviceBarrierSubscription?.cancel();

    if (!_useFirebase) {
      final diagnostics = await DeviceBarrierService.instance.loadLocalDiagnostics();
      if (!mounted) return;
      setState(() {
        _deviceBarriers = diagnostics.barriers;
        _batteryLevel = diagnostics.batteryLevel;
        _batteryState = diagnostics.batteryState;
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
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _deviceBarriers = const [];
              _batteryLevel = null;
              _batteryState = null;
            });
          },
        );
  }

  Future<void> _loadBpmAndLembretes() async {
    if (!_isConnected) return;
    await LembreteService.instance.carregar();
    await SmartAlertService.instance.atualizar(
      LembreteService.instance.lembretes,
      eventos: LembreteService.instance.eventos,
      bpm: _lastBpm,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final bpm = prefs.getInt('last_bpm_value');
      final idosoId = await SessionRoleService.getActiveIdosoId();

      String nome = 'Idoso';
      String telefone = '';
      String endereco = '';
      if (_useFirebase) {
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null) {
          nome = doc.data()!['nome'] as String? ?? 'Idoso';
          telefone = doc.data()!['telefone'] as String? ?? '';
          endereco = doc.data()!['endereco'] as String? ?? '';
        }
      } else {
        final jsonStr = prefs.getString('idoso_perfil');
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          nome = data['nome'] as String? ?? 'Idoso';
          telefone = data['telefone'] as String? ?? '';
          endereco = data['endereco'] as String? ?? '';
        }
      }

      if (mounted) {
        await SmartAlertService.instance.atualizar(
          LembreteService.instance.lembretes,
          eventos: LembreteService.instance.eventos,
          bpm: bpm,
        );
        if (!mounted) return;
        setState(() {
          _lastBpm = bpm;
          _isLoadingBpm = false;
          _nomeIdoso = nome.split(' ').first;
          _telefoneIdoso = telefone;
          _enderecoIdoso = endereco;
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

  Future<void> _sendQuickMessage() async {
    final text = _quickMessageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingQuickMessage = true);
    try {
      await MessageService.instance.sendText(text);
      _quickMessageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao enviar mensagem.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingQuickMessage = false);
      }
    }
  }

  Future<void> _enviarReforco(BuildContext context, Lembrete lembrete) async {
    setState(() => _refortIsLoading = true);
    try {
      await MessageService.instance.sendText(
        'Reforco do cuidador: $_nomeIdoso, por favor confira agora o lembrete "${lembrete.titulo}".',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reforco enviado como mensagem para o idoso.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel enviar o reforco: $e'),
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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
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
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          _buildTodayWelfareStatusSection(),
                          const SizedBox(height: 24),
                          _buildMoodHistoryChart(),
                          const SizedBox(height: 24),
                          _buildSmartAlertsSection(),
                          if (_smartAlerts.isNotEmpty) const SizedBox(height: 24),
                          _buildDeviceBarrierSection(),
                          if (_deviceBarriers.isNotEmpty) const SizedBox(height: 24),
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
                'Para receber e visualizar as informações em tempo real (lembretes, alertas e batimentos cardíacos), você precisa conectar o seu painel ao dispositivo do idoso utilizando o código de 6 dígitos gerado no aplicativo dele.',
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
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
          Icon(
            _useFirebase ? Icons.cloud_done : Icons.cloud_off,
            color: _useFirebase ? Colors.green : AppColors.outline,
            size: 20,
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/emergency-alert'),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber, color: AppColors.error, size: 24),
            ),
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
            )
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
            if (_enderecoIdoso.isNotEmpty) ...[
              const Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_enderecoIdoso)}';
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
            ]
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
              child: const Row(
                children: [
                  Icon(Icons.forum, color: AppColors.primary, size: 34),
                  SizedBox(width: 14),
                  Expanded(
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
                          'Envie uma mensagem instantânea para o idoso.',
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
            const Divider(height: 24, color: AppColors.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickMessageController,
                    decoration: InputDecoration(
                      hintText: 'Escreva um recado rápido...',
                      hintStyle: const TextStyle(fontSize: 15),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendingQuickMessage ? null : _sendQuickMessage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _sendingQuickMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
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
                )
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
    final list = LembreteService.instance.lembretes;
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
                    if (_telefoneIdoso.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final Uri launchUri = Uri(scheme: 'tel', path: _telefoneIdoso);
                          if (await canLaunchUrl(launchUri)) {
                            await launchUrl(launchUri);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, color: AppColors.primary, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Ligar',
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
                            todosTomados ? 'Tudo em dia!' : 'Pendências de hoje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: todosTomados ? Colors.green : AppColors.secondary,
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
                                  color: AppColors.onSurfaceVariant),
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
                                  color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _batteryLevel != null ? '$_batteryLevel%' : '--',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: _batteryLevel != null && _batteryLevel! <= 15
                                      ? AppColors.error
                                      : (_batteryState == 'charging'
                                          ? Colors.green
                                          : AppColors.secondary)),
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

  Widget _buildHealthSnapshot() {
    final bpmText = _isLoadingBpm
        ? '--'
        : (_lastBpm != null ? '$_lastBpm' : '--');
    final statusText = _isLoadingBpm
        ? 'CARREGANDO'
        : (_lastBpm != null ? 'LIDO DA CÂMERA' : 'SEM MEDIÇÃO');

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
          if (_lastBpm != null && !_isLoadingBpm) ...[
            const SizedBox(height: 16),
            EcgHeartbeatWidget(bpm: _lastBpm!),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final Map<String, String> categories = {
      'Todos': 'Todos',
      'medicacao': 'Remédios',
      'refeicoes': 'Refeições',
      'exercicio': 'Exercícios',
      'hidratacao': 'Água',
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

  Widget _buildTodayReminders(BuildContext context) {
    final rawList = LembreteService.instance.lembretes;
    final filteredList = _selectedCategoryFilter == 'Todos'
        ? rawList
        : rawList.where((l) => l.categoria == _selectedCategoryFilter).toList();

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
        const SizedBox(height: 12),
        _buildCategoryFilters(),
        const SizedBox(height: 16),
        AudioPlayerCard(
          accentColor: AppColors.primary,
          subtitle: 'Ouça todos os lembretes do dia',
          textsToSpeak: filteredList.isEmpty
              ? ['Nenhum lembrete cadastrado para hoje nesta categoria.']
              : [
                  'Lembretes de hoje para $_nomeIdoso:',
                  ...filteredList.map((l) => '${l.titulo} às ${l.horarioFormatado}.'),
                ],
        ),
        const SizedBox(height: 16),
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
            final bool isPending = status == ReminderStatus.scheduled || status == ReminderStatus.late;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status == ReminderStatus.late ? AppColors.error : AppColors.outlineVariant,
                    width: status == ReminderStatus.late ? 2 : 1,
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
                    if (isPending) ...[
                      const Divider(height: 1, color: AppColors.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.volume_up, size: 16),
                                label: const Text(
                                  'Enviar Reforço Sonoro',
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
                    icon: const Icon(Icons.photo_library_outlined,
                        size: 20),
                    label: const Text(
                      'Ver Galeria de Fotos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
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

  /// Builds the 7-day mood history chart for the supervisor dashboard.
  Widget _buildMoodHistoryChart() {
    final now = DateTime.now();
    final eventos = LembreteService.instance.eventos
        .where((e) => e.categoria == 'bem_estar')
        .toList();

    // Build a map: dateKey -> last observacao of that day
    final Map<String, String?> moodByDay = {};
    for (final e in eventos) {
      final key =
          '${e.registradoEm.year}-${e.registradoEm.month.toString().padLeft(2, '0')}-${e.registradoEm.day.toString().padLeft(2, '0')}';
      // Keep the most recent entry per day
      if (!moodByDay.containsKey(key)) {
        moodByDay[key] = e.observacao;
      }
    }

    final dayLabels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mood, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Humor — Últimos 7 dias',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              // index 0 = 6 days ago, index 6 = today
              final day = DateTime(
                  now.year, now.month, now.day - (6 - index));
              final key =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final mood = moodByDay[key];
              final dayLabel = dayLabels[day.weekday % 7];
              final isToday = index == 6;

              Color circleColor;
              String emoji;
              String tooltip;

              if (mood == null) {
                circleColor = AppColors.surfaceContainerHigh;
                emoji = '—';
                tooltip = 'Sem check-in';
              } else if (mood.contains('Preciso de ajuda')) {
                circleColor = AppColors.errorContainer;
                emoji = '🔴';
                tooltip = mood;
              } else if (mood.contains('Mais ou menos')) {
                circleColor = const Color(0xFFFFF9C4);
                emoji = '🟡';
                tooltip = mood;
              } else {
                circleColor = AppColors.tertiaryFixed;
                emoji = '🟢';
                tooltip = mood;
              }

              return Tooltip(
                message: tooltip,
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(
                                color: AppColors.primary, width: 2.5)
                            : Border.all(
                                color: AppColors.outlineVariant, width: 1),
                      ),
                      child: Center(
                        child: mood == null
                            ? Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.outline,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text(
                                emoji,
                                style:
                                    const TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday
                            ? FontWeight.w900
                            : FontWeight.w500,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _moodLegendItem('🟢', 'Bem', AppColors.tertiaryFixed),
              const SizedBox(width: 12),
              _moodLegendItem('🟡', 'Mais ou menos',
                  const Color(0xFFFFF9C4)),
              const SizedBox(width: 12),
              _moodLegendItem('🔴', 'Preciso de ajuda',
                  AppColors.errorContainer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodLegendItem(String emoji, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  LembreteEvento? _getTodayWelfareCheckin() {
    final now = DateTime.now();
    final todayEvents = LembreteService.instance.eventos.where((e) {
      return e.categoria == 'bem_estar' &&
          e.registradoEm.year == now.year &&
          e.registradoEm.month == now.month &&
          e.registradoEm.day == now.day;
    }).toList();
    if (todayEvents.isEmpty) return null;
    todayEvents.sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
    return todayEvents.first;
  }

  Widget _buildTodayWelfareStatusSection() {
    final todayCheckin = _getTodayWelfareCheckin();

    Color bgColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;
    String statusTitle;
    String statusDesc;

    if (todayCheckin == null) {
      bgColor = AppColors.surfaceContainerHigh;
      borderColor = AppColors.outlineVariant;
      textColor = AppColors.onSurfaceVariant;
      iconColor = AppColors.outline;
      icon = Icons.calendar_today;
      statusTitle = 'Check-in de Hoje';
      statusDesc = 'O idoso ainda não realizou o check-in de bem-estar hoje.';
    } else {
      final obs = todayCheckin.observacao ?? '';
      if (obs.contains('Preciso de ajuda')) {
        bgColor = AppColors.errorContainer;
        borderColor = AppColors.error.withValues(alpha: 0.5);
        textColor = AppColors.error;
        iconColor = AppColors.error;
        icon = Icons.warning;
        statusTitle = 'Atenção: Idoso precisa de ajuda!';
        statusDesc = 'Resposta do idoso: "$obs"';
      } else if (obs.contains('Mais ou menos')) {
        bgColor = AppColors.secondaryFixed;
        borderColor = AppColors.onSecondaryFixedVariant.withValues(alpha: 0.5);
        textColor = AppColors.onSecondaryFixed;
        iconColor = AppColors.onSecondaryFixedVariant;
        icon = Icons.sentiment_neutral;
        statusTitle = 'Check-in: Indisposto';
        statusDesc = 'Resposta do idoso: "$obs"';
      } else {
        bgColor = AppColors.tertiaryFixed;
        borderColor = AppColors.onTertiaryFixedVariant.withValues(alpha: 0.5);
        textColor = AppColors.onTertiaryFixed;
        iconColor = AppColors.onTertiaryFixedVariant;
        icon = Icons.sentiment_very_satisfied;
        statusTitle = 'Check-in: Tudo bem!';
        statusDesc = 'O idoso respondeu que está se sentindo bem hoje.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EcgHeartbeatWidget extends StatefulWidget {
  final int bpm;
  const EcgHeartbeatWidget({super.key, required this.bpm});

  @override
  State<EcgHeartbeatWidget> createState() => _EcgHeartbeatWidgetState();
}

class _EcgHeartbeatWidgetState extends State<EcgHeartbeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _points = [];
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _controller.addListener(_updatePoints);
    for (int i = 0; i < 60; i++) {
      _points.add(0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePoints() {
    _tickCount++;
    double base = 0.0;
    int period = (3600 ~/ (widget.bpm > 0 ? widget.bpm : 70)).clamp(20, 100);
    int phase = _tickCount % period;

    if (phase == 0) {
      base = 4.0;
    } else if (phase == 2) {
      base = -4.0;
    } else if (phase == 4) {
      base = 32.0;
    } else if (phase == 6) {
      base = -10.0;
    } else if (phase == 10) {
      base = 6.0;
    } else {
      base = (phase % 4 == 0) ? 0.6 : ((phase % 5 == 0) ? -0.6 : 0.0);
    }

    if (mounted) {
      setState(() {
        _points.removeAt(0);
        _points.add(base);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: EcgPainter(_points),
        ),
      ),
    );
  }
}

class EcgPainter extends CustomPainter {
  final List<double> dataPoints;
  EcgPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const gridSpacing = 12.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final path = Path();
    final double step = size.width / (dataPoints.length - 1);

    path.moveTo(0, size.height / 2 - dataPoints[0]);
    for (int i = 1; i < dataPoints.length; i++) {
      path.lineTo(i * step, size.height / 2 - dataPoints[i]);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) => true;
}
