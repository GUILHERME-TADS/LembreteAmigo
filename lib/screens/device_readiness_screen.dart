import 'package:flutter/material.dart';

import '../models/device_barrier.dart';
import '../models/device_diagnostics.dart';
import '../models/lembrete.dart';
import '../services/alarm_service.dart';
import '../services/app_permission_service.dart';
import '../services/device_barrier_service.dart';
import '../services/lembrete_service.dart';
import '../services/notification_service.dart';
import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';

class DeviceReadinessScreen extends StatefulWidget {
  const DeviceReadinessScreen({super.key});

  @override
  State<DeviceReadinessScreen> createState() => _DeviceReadinessScreenState();
}

class _DeviceReadinessScreenState extends State<DeviceReadinessScreen> {
  bool _loading = true;
  bool _testingAlarm = false;
  bool _repairing = false;
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

  Future<void> _repairAll() async {
    if (_repairing) return;
    setState(() => _repairing = true);
    try {
      await AppPermissionService.instance.requestAll();
      await OfflineSyncService.instance.retryFailedWrites();
      await LembreteService.instance.carregar();
      await NotificationService.instance.agendarTodos(
        LembreteService.instance.lembretes,
      );
      await _refresh();
      if (!mounted) return;
      final message = _ready
          ? 'Pronto. Permissões, agenda e sincronização foram verificadas.'
          : 'A verificação terminou. Alguns itens ainda precisam ser liberados nas configurações.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível concluir o reparo. Tente novamente ou abra as configurações.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
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
      final scheduled = await AlarmService.instance.agendarAlarmeLembrete(
        reminder,
        now.add(const Duration(seconds: 5)),
        'assets/alarm.mp3',
        testId,
      );
      if (!mounted) return;
      if (!scheduled) {
        await DeviceBarrierService.instance.recordAlarmTest(successful: false);
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O celular bloqueou o teste. Use Reparar agora e libere notificações e alarmes exatos.',
            ),
          ),
        );
        return;
      }
      final successful = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.alarm_on, color: AppColors.primary, size: 48),
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
            const SizedBox(height: 10),
            _buildRepairButton(),
            const SizedBox(height: 10),
            _buildSyncStatus(),
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
              Card(
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
    final color = _ready ? AppColors.vitalHealthy : AppColors.warning;
    return Semantics(
      liveRegion: true,
      label: _ready
          ? 'Celular pronto para os lembretes'
          : 'O celular precisa de atenção',
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _ready ? Icons.verified_rounded : Icons.build_circle_rounded,
                color: color,
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _ready ? 'Celular 100% Pronto!' : 'Vamos conferir o aparelho',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _ready
                  ? 'Som, bateria e sincronização estão operando perfeitamente.'
                  : 'Resolva os avisos abaixo para garantir que nenhum remédio atrase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                height: 1.3,
              ),
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
        icon: const Icon(Icons.alarm_rounded, size: 30),
        label: Text(
          _testingAlarm ? 'Testando o som...' : 'Testar som do alarme agora',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildRepairButton() {
    return SizedBox(
      height: 64,
      child: OutlinedButton.icon(
        onPressed: _loading || _repairing ? null : _repairAll,
        icon: _repairing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.auto_fix_high_rounded, size: 28),
        label: Text(
          _repairing ? 'Ajustando permissões...' : 'Corrigir automaticamente',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncService.instance.pendingCount,
      builder: (context, pending, _) {
        final synced = pending == 0;
        return Card(
          child: ListTile(
            leading: Icon(
              synced ? Icons.cloud_done : Icons.cloud_upload,
              color: synced ? AppColors.success : AppColors.warning,
              size: 32,
            ),
            title: Text(
              synced
                  ? 'Dados sincronizados'
                  : '$pending ação(ões) aguardando envio',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              synced
                  ? 'As confirmações deste celular estão atualizadas.'
                  : 'Nada será perdido. O envio acontece quando a internet voltar.',
            ),
            trailing: synced
                ? null
                : TextButton(
                    onPressed: _repairing
                        ? null
                        : OfflineSyncService.instance.retryFailedWrites,
                    child: const Text('Enviar'),
                  ),
          ),
        );
      },
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
