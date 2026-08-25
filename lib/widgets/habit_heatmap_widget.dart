import 'package:flutter/material.dart';
import '../models/lembrete_evento.dart';
import '../theme/app_theme.dart';

/// Mapa de Calor do Hábito e Ritmo Semanal de Tomada de Remédios para o Supervisor
class HabitHeatmapWidget extends StatelessWidget {
  final List<LembreteEvento> eventos;
  final int daysCount;

  const HabitHeatmapWidget({
    super.key,
    required this.eventos,
    this.daysCount = 28,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Mapear eventos por dia
    final dayStatusMap = <DateTime, ({int completed, int total})>{};
    for (int i = daysCount - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      dayStatusMap[d] = (completed: 0, total: 0);
    }

    for (final ev in eventos) {
      final evDate = DateTime(
        ev.registradoEm.year,
        ev.registradoEm.month,
        ev.registradoEm.day,
      );
      if (dayStatusMap.containsKey(evDate)) {
        final current = dayStatusMap[evDate]!;
        final isCompleted = ev.status.isConcluido;
        dayStatusMap[evDate] = (
          completed: current.completed + (isCompleted ? 1 : 0),
          total: current.total + 1,
        );
      }
    }

    final dayEntries = dayStatusMap.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_view_month_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ritmo de Hábitos (Últimas 4 Semanas)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mapa de regularidade diária do tratamento',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Cabeçalho dos dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayLabel('D'),
              _WeekdayLabel('S'),
              _WeekdayLabel('T'),
              _WeekdayLabel('Q'),
              _WeekdayLabel('Q'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),

          // Grade de 28 Dias (7x4)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayEntries.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final entry = dayEntries[index];
              final date = entry.key;
              final data = entry.value;

              Color cellColor;
              if (data.total == 0) {
                cellColor = AppColors.surfaceContainerHigh;
              } else if (data.completed == data.total) {
                cellColor = const Color(0xFF2E7D32); // 100%
              } else if (data.completed > 0) {
                cellColor = const Color(0xFFFFA000); // Parcial
              } else {
                cellColor = const Color(0xFFD32F2F); // Perdido
              }

              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return Tooltip(
                message:
                    '${date.day}/${date.month}: ${data.completed}/${data.total} tomados',
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: Colors.black, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: cellColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: data.total == 0
                            ? AppColors.onSurfaceVariant
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Legenda Explicativa
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _LegendItem(color: const Color(0xFF2E7D32), label: '100% em dia'),
              _LegendItem(color: const Color(0xFFFFA000), label: 'Parcial'),
              _LegendItem(color: const Color(0xFFD32F2F), label: 'Perdido'),
              _LegendItem(
                color: AppColors.surfaceContainerHigh,
                label: 'Sem registros',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
