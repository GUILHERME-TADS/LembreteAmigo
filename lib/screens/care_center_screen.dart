import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/care_alert.dart';
import '../services/care_alert_service.dart';
import '../services/session_role_service.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class CareCenterScreen extends StatefulWidget {
  const CareCenterScreen({super.key});

  @override
  State<CareCenterScreen> createState() => _CareCenterScreenState();
}

class _CareCenterScreenState extends State<CareCenterScreen> {
  late final Future<String?> _elderlyId;
  CareAlertStatus? _filter;
  final Set<String> _busyAlerts = {};

  @override
  void initState() {
    super.initState();
    _elderlyId = SessionRoleService.getVerifiedActiveIdosoId();
  }

  Future<void> _acknowledge(CareAlert alert) async {
    if (_busyAlerts.contains(alert.id)) return;
    setState(() => _busyAlerts.add(alert.id));
    try {
      await CareAlertService.instance.acknowledge(alert.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pendência assumida por você.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível assumir: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAlerts.remove(alert.id));
    }
  }

  Future<void> _resolve(CareAlert alert) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolver pendência'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'O que foi feito? (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Marcar como resolvida'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busyAlerts.contains(alert.id)) {
      controller.dispose();
      return;
    }
    setState(() => _busyAlerts.add(alert.id));
    try {
      await CareAlertService.instance.resolve(
        alert.id,
        resolution: controller.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pendência resolvida.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível resolver: $error')),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _busyAlerts.remove(alert.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/care-center'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.none,
      ),
      appBar: AppBar(
        title: const Text('Central de Pendências'),
        backgroundColor: AppColors.surface,
      ),
      body: FutureBuilder<String?>(
        future: _elderlyId,
        builder: (context, idSnapshot) {
          if (idSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final elderlyId = idSnapshot.data;
          if (elderlyId == null || elderlyId.isEmpty) {
            return const _EmptyCenter(
              icon: Icons.link_off,
              title: 'Nenhuma pessoa conectada',
              message: 'Conecte o aplicativo da pessoa idosa para acompanhar.',
            );
          }
          return StreamBuilder<List<CareAlert>>(
            stream: CareAlertService.instance.watchAlerts(elderlyId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _EmptyCenter(
                  icon: Icons.cloud_off,
                  title: 'Não foi possível carregar',
                  message: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final visible = _filter == null
                  ? all
                  : all.where((item) => item.status == _filter).toList();
              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  children: [
                    _summary(all),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip('Todas', null),
                        _filterChip('Abertas', CareAlertStatus.open),
                        _filterChip('Assumidas', CareAlertStatus.acknowledged),
                        _filterChip('Resolvidas', CareAlertStatus.resolved),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (visible.isEmpty)
                      const _EmptyCenter(
                        icon: Icons.task_alt,
                        title: 'Tudo em dia',
                        message: 'Não há pendências neste filtro.',
                      )
                    else
                      for (final alert in visible) ...[
                        _alertCard(alert),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _summary(List<CareAlert> alerts) {
    final open = alerts.where((item) => item.isOpen).length;
    final acknowledged = alerts.where((item) => item.isAcknowledged).length;
    final urgent = alerts
        .where((item) => !item.isResolved && item.severity == 3)
        .length;
    return Card(
      color: urgent > 0 ? AppColors.errorContainer : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              urgent > 0 ? Icons.notification_important : Icons.task_alt,
              color: urgent > 0 ? AppColors.error : AppColors.primary,
              size: 38,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgent > 0 ? '$urgent urgente(s)' : 'Nenhum alerta urgente',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('$open aberta(s) • $acknowledged assumida(s)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, CareAlertStatus? value) {
    return FilterChip(
      selected: _filter == value,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _alertCard(CareAlert alert) {
    final color = alert.severity == 3
        ? AppColors.error
        : alert.severity == 2
        ? AppColors.warning
        : AppColors.primary;
    final statusLabel = switch (alert.status) {
      CareAlertStatus.open => 'ABERTA',
      CareAlertStatus.acknowledged => 'ASSUMIDA',
      CareAlertStatus.resolved => 'RESOLVIDA',
    };
    final busy = _busyAlerts.contains(alert.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(alert.type), color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: color.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt.toLocal()),
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            if (alert.resolution?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Solução: ${alert.resolution}'),
            ],
            if (!alert.isResolved) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (alert.isOpen)
                    FilledButton.icon(
                      onPressed: busy ? null : () => _acknowledge(alert),
                      icon: const Icon(Icons.person_pin_circle),
                      label: const Text('Assumir'),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _resolve(alert),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Resolver'),
                  ),
                  if (alert.type == 'low_stock')
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/medication-stock'),
                      icon: const Icon(Icons.medication),
                      label: const Text('Ver estoque'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'low_stock' => Icons.inventory_2,
      'help_request' => Icons.sos,
      'device_barrier' => Icons.phone_android,
      _ => Icons.alarm_off,
    };
  }
}

class _EmptyCenter extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCenter({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
