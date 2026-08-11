import 'package:flutter/material.dart';

import '../models/device_barrier.dart';
import '../models/device_diagnostics.dart';
import '../models/lembrete.dart';
import '../services/alarm_service.dart';
import '../services/app_permission_service.dart';
import '../services/device_barrier_service.dart';
import '../theme/app_theme.dart';

class DeviceReadinessScreen extends StatefulWidget {
  const DeviceReadinessScreen({super.key});

  @override
  State<DeviceReadinessScreen> createState() => _DeviceReadinessScreenState();
}

class _DeviceReadinessScreenState extends State<DeviceReadinessScreen> {
  bool _loading = true;
  bool _testingAlarm = false;
  List<AppPermissionItem> _permissions = const [];
  DeviceDiagnostics _diagnostics = const DeviceDiagnostics(barriers: []);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await DeviceBarrierService.instance.refresh(
      markElderlyActive: true,
      publish: true,
    );
    final permissions = await AppPermissionService.instance.statuses();
    final diagnostics = await DeviceBarrierService.instance
        .loadLocalDiagnostics();
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _diagnostics = diagnostics;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await AppPermissionService.instance.openSettings();
    await _refresh();
  }

  Future<void> _testAlarm() async {
    if (_testingAlarm) return;
    setState(() => _testingAlarm = true);
    const testId = 991337;
    try {
      final now = DateTime.now();
      final reminder = Lembrete(
        id: 'device_readiness_test',
        titulo: 'Teste do Lembrete Amigo',
        horarioHour: now.hour,
        horarioMinute: now.minute,
        recorrencia: 'unico',
        lembreteUnico: true,
        dataInicio: now,
      );
      await AlarmService.instance.agendarAlarmeLembrete(
        reminder,
        now.add(const Duration(seconds: 5)),
        'assets/alarm.mp3',
        testId,
      );
      if (!mounted) return;
      final successful = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.alarm_on, color: AppColors.primary, size: 48),
          title: const Text('Teste agendado'),
          content: const Text(
            'O som deve tocar em aproximadamente 5 segundos. '
            'Quando ouvir, toque em “Parar teste”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Não ouvi'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.hearing),
              label: const Text('Ouvi o alarme'),
            ),
          ],
        ),
      );
      if (successful != null) {
        await DeviceBarrierService.instance.recordAlarmTest(
          successful: successful,
        );
        await _refresh();
      }
    } finally {
      await AlarmService.instance.cancelar(testId);
      if (mounted) setState(() => _testingAlarm = false);
    }
  }

  bool get _ready =>
      _permissions.every((item) => item.granted) &&
      !_diagnostics.barriers.any(
        (barrier) => barrier.severity == DeviceBarrierSeverity.critical,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('O celular está pronto?')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSummary(),
            const SizedBox(height: 20),
            _buildAlarmTest(),
            if (_diagnostics.lastAlarmTestAt != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    _diagnostics.lastAlarmTestSuccessful == true
                        ? Icons.check_circle
                        : Icons.error,
                    color: _diagnostics.lastAlarmTestSuccessful == true
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  title: Text(
                    _diagnostics.lastAlarmTestSuccessful == true
                        ? 'Último teste funcionou'
                        : 'Último teste não foi ouvido',
                  ),
                  subtitle: Text(
                    'Testado em '
                    '${_diagnostics.lastAlarmTestAt!.day.toString().padLeft(2, '0')}/'
                    '${_diagnostics.lastAlarmTestAt!.month.toString().padLeft(2, '0')} '
                    'às '
                    '${_diagnostics.lastAlarmTestAt!.hour.toString().padLeft(2, '0')}:'
                    '${_diagnostics.lastAlarmTestAt!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Permissões importantes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._permissions.map(_buildPermissionTile),
            const SizedBox(height: 20),
            const Text(
              'Condições do aparelho',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (!_loading && _diagnostics.barriers.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 34,
                  ),
                  title: Text(
                    'Nenhum problema detectado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Som, conexão e sincronização parecem disponíveis.',
                  ),
                ),
              )
            else
              ..._diagnostics.barriers.map(_buildBarrierTile),
            if (_diagnostics.batteryLevel != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.battery_full, size: 32),
                  title: const Text(
                    'Bateria',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${_diagnostics.batteryLevel}% • '
                    '${_diagnostics.batteryState ?? 'estado desconhecido'}',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final color = _ready ? AppColors.success : AppColors.warning;
    return Semantics(
      liveRegion: true,
      label: _ready
          ? 'Celular pronto para os lembretes'
          : 'O celular precisa de atenção',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 3),
        ),
        child: Column(
          children: [
            Icon(
              _ready ? Icons.verified : Icons.build_circle_outlined,
              color: color,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              _ready ? 'Tudo pronto!' : 'Vamos conferir o celular',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _ready
                  ? 'Os lembretes estão com as condições principais disponíveis.'
                  : 'Resolva os itens abaixo para reduzir atrasos nos lembretes.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTest() {
    return SizedBox(
      height: 72,
      child: FilledButton.icon(
        onPressed: _loading || _testingAlarm ? null : _testAlarm,
        icon: const Icon(Icons.alarm, size: 30),
        label: Text(
          _testingAlarm ? 'Testando...' : 'Testar lembrete agora',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPermissionTile(AppPermissionItem item) {
    return Card(
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(
          item.granted ? Icons.check_circle : Icons.error,
          color: item.granted ? AppColors.success : AppColors.error,
          size: 32,
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(item.description),
        trailing: item.granted
            ? null
            : TextButton(
                onPressed: _openSettings,
                child: const Text('Corrigir'),
              ),
      ),
    );
  }

  Widget _buildBarrierTile(DeviceBarrier barrier) {
    final color = switch (barrier.severity) {
      DeviceBarrierSeverity.critical => AppColors.error,
      DeviceBarrierSeverity.warning => AppColors.warning,
      DeviceBarrierSeverity.info => AppColors.primary,
    };
    return Card(
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(Icons.info, color: color, size: 32),
        title: Text(
          barrier.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(barrier.message),
        trailing: TextButton(
          onPressed: _openSettings,
          child: const Text('Corrigir'),
        ),
      ),
    );
  }
}
