import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lembrete.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class ElderlyDailyTimeline extends StatelessWidget {
  final List<Lembrete> lembretes;
  final VoidCallback? onRefresh;

  const ElderlyDailyTimeline({
    super.key,
    required this.lembretes,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayReminders = lembretes
        .where((l) => l.isActiveOn(now))
        .toList()
      ..sort((a, b) {
        final aMin = a.horarioHour * 60 + a.horarioMinute;
        final bMin = b.horarioHour * 60 + b.horarioMinute;
        return aMin.compareTo(bMin);
      });

    if (todayReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = todayReminders.length;
    final concluidos = todayReminders.where((l) => l.concluido).length;

    // Agrupamento por períodos do dia
    final manha = todayReminders
        .where((l) => l.horarioHour >= 5 && l.horarioHour < 12)
        .toList();
    final tarde = todayReminders
        .where((l) => l.horarioHour >= 12 && l.horarioHour < 18)
        .toList();
    final noite = todayReminders
        .where((l) => l.horarioHour >= 18 || l.horarioHour < 5)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minha Rotina de Hoje',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$concluidos de $total concluídos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: concluidos == total && total > 0
                              ? AppColors.success
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (concluidos == total && total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: AppColors.onSuccessContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tudo em dia!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSuccessContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (manha.isNotEmpty) ...[
              _buildPeriodSection(
                context,
                title: 'Manhã',
                icon: Icons.wb_sunny_rounded,
                color: AppColors.morning,
                containerColor: AppColors.morningContainer,
                reminders: manha,
              ),
            ],
            if (tarde.isNotEmpty) ...[
              _buildPeriodSection(
                context,
                title: 'Tarde',
                icon: Icons.wb_twilight_rounded,
                color: AppColors.afternoon,
                containerColor: AppColors.afternoonContainer,
                reminders: tarde,
              ),
            ],
            if (noite.isNotEmpty) ...[
              _buildPeriodSection(
                context,
                title: 'Noite',
                icon: Icons.bedtime_rounded,
                color: AppColors.night,
                containerColor: AppColors.nightContainer,
                reminders: noite,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Color containerColor,
    required List<Lembrete> reminders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1.5,
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        ...reminders.map((lembrete) => _buildTimelineItem(context, lembrete)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, Lembrete lembrete) {
    final hora = lembrete.horarioHour.toString().padLeft(2, '0');
    final min = lembrete.horarioMinute.toString().padLeft(2, '0');
    final horarioStr = '$hora:$min';

    final isConcluido = lembrete.concluido;
    final isMedicamento = lembrete.categoria == 'medicacao';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isConcluido
            ? AppColors.successContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            HapticFeedback.lightImpact();
            final statusText = isConcluido
                ? 'Você já concluiu o lembrete ${lembrete.titulo} de $horarioStr.'
                : 'Lembrete ${lembrete.titulo} previsto para às $horarioStr.';
            TTSService.instance.falar(statusText);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isConcluido
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.outlineVariant.withValues(alpha: 0.6),
                width: isConcluido ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isConcluido
                        ? AppColors.success
                        : (isMedicamento
                            ? AppColors.medicationContainer
                            : AppColors.primaryContainer),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isConcluido
                          ? Icons.check_rounded
                          : (isMedicamento
                              ? Icons.medication_rounded
                              : Icons.alarm_rounded),
                      color: isConcluido
                          ? AppColors.onPrimary
                          : (isMedicamento
                              ? AppColors.onMedicationContainer
                              : AppColors.onPrimaryContainer),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lembrete.titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isConcluido
                              ? AppColors.onSuccessContainer
                              : AppColors.onSurface,
                          decoration: isConcluido
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: isConcluido
                                ? AppColors.onSuccessContainer
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            horarioStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isConcluido
                                  ? AppColors.onSuccessContainer
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isConcluido
                        ? AppColors.successContainer
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isConcluido
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isConcluido ? 'Tomei ✓' : 'Aguardando',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isConcluido
                          ? AppColors.onSuccessContainer
                          : AppColors.onWarningContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
