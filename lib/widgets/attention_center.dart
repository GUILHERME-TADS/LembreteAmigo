import 'package:flutter/material.dart';

import '../models/device_barrier.dart';
import '../models/smart_alert.dart';
import '../theme/app_theme.dart';

class AttentionCenter extends StatelessWidget {
  final List<SmartAlert> alerts;
  final List<DeviceBarrier> barriers;
  final int? batteryLevel;
  final bool diagnosticsStale;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDeviceReadiness;
  final VoidCallback onRefresh;

  const AttentionCenter({
    super.key,
    required this.alerts,
    required this.barriers,
    required this.batteryLevel,
    required this.diagnosticsStale,
    required this.onCall,
    required this.onMessage,
    required this.onOpenHistory,
    required this.onOpenDeviceReadiness,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        <_AttentionEntry>[
          ...alerts.map(_AttentionEntry.fromAlert),
          ...barriers.map(_AttentionEntry.fromBarrier),
          if (diagnosticsStale)
            _AttentionEntry(
              title: 'Celular sem diagnóstico recente',
              message:
                  'Abra a verificação do aparelho para confirmar se os avisos estão funcionando.',
              severity: 2,
              createdAt: DateTime.now(),
              isDeviceIssue: true,
            ),
        ]..sort((a, b) {
          final severity = b.severity.compareTo(a.severity);
          return severity != 0 ? severity : b.createdAt.compareTo(a.createdAt);
        });
    final criticalCount = entries.where((entry) => entry.severity == 3).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: criticalCount > 0
              ? AppColors.error
              : AppColors.primary.withValues(alpha: 0.22),
          width: criticalCount > 0 ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                criticalCount > 0
                    ? Icons.notification_important
                    : Icons.health_and_safety_outlined,
                color: criticalCount > 0 ? AppColors.error : AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Central de atenção',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              if (batteryLevel != null)
                Chip(
                  avatar: const Icon(Icons.battery_std, size: 18),
                  label: Text('$batteryLevel%'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entries.isEmpty
                ? 'Tudo certo agora. Nenhuma ação urgente.'
                : '${entries.length} item(ns) por prioridade'
                      '${criticalCount > 0 ? ' • $criticalCount urgente(s)' : ''}',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const _AllClearCard()
          else
            for (final entry in entries.take(5)) ...[
              _AttentionCard(
                entry: entry,
                onPrimaryAction: entry.isDeviceIssue
                    ? onOpenDeviceReadiness
                    : onOpenHistory,
                onCall: onCall,
                onMessage: onMessage,
              ),
              const SizedBox(height: 10),
            ],
          Row(
            children: [
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
              const Spacer(),
              if (entries.length > 5)
                Text(
                  '+ ${entries.length - 5} item(ns)',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionEntry {
  final String title;
  final String message;
  final int severity;
  final DateTime createdAt;
  final bool isDeviceIssue;

  const _AttentionEntry({
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.isDeviceIssue,
  });

  factory _AttentionEntry.fromAlert(SmartAlert alert) => _AttentionEntry(
    title: alert.title,
    message: alert.message,
    severity: switch (alert.severity) {
      SmartAlertSeverity.critical => 3,
      SmartAlertSeverity.warning => 2,
      SmartAlertSeverity.info => 1,
    },
    createdAt: alert.createdAt,
    isDeviceIssue: false,
  );

  factory _AttentionEntry.fromBarrier(DeviceBarrier barrier) => _AttentionEntry(
    title: barrier.title,
    message: barrier.message,
    severity: switch (barrier.severity) {
      DeviceBarrierSeverity.critical => 3,
      DeviceBarrierSeverity.warning => 2,
      DeviceBarrierSeverity.info => 1,
    },
    createdAt: barrier.detectedAt,
    isDeviceIssue: true,
  );
}

class _AttentionCard extends StatelessWidget {
  final _AttentionEntry entry;
  final VoidCallback onPrimaryAction;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  const _AttentionCard({
    required this.entry,
    required this.onPrimaryAction,
    required this.onCall,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.severity == 3
        ? AppColors.error
        : entry.severity == 2
        ? const Color(0xFFE07A00)
        : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.message,
            style: const TextStyle(fontSize: 15, height: 1.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPrimaryAction,
                icon: Icon(
                  entry.isDeviceIssue ? Icons.phone_android : Icons.history,
                ),
                label: Text(
                  entry.isDeviceIssue ? 'Ver celular' : 'Ver histórico',
                ),
              ),
              if (!entry.isDeviceIssue) ...[
                OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call),
                  label: const Text('Ligar'),
                ),
                OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Mensagem'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sem atrasos ou barreiras no aparelho.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
