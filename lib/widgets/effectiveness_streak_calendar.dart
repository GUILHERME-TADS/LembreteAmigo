import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/effectiveness_metrics.dart';

class EffectivenessStreakCalendar extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final List<DailyEffectiveness> dailyTrend;

  const EffectivenessStreakCalendar({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.dailyTrend,
  });

  @override
  Widget build(BuildContext context) {
    final last7 = dailyTrend.length >= 7
        ? dailyTrend.sublist(dailyTrend.length - 7)
        : List.from(dailyTrend);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department,
              color: AppColors.warning,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              '$currentStreak dias consecutivos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        if (bestStreak > currentStreak) ...[
          const SizedBox(height: 2),
          Text(
            'Recorde: $bestStreak dias',
            style: TextStyle(fontSize: 13, color: AppColors.outline),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: last7.map((day) {
            final dayLabel = _dayAbbr(day.date.weekday);
            final hasData = day.score >= 0;
            final isGood = hasData && day.score >= 80;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasData
                        ? (isGood
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.1))
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: hasData
                        ? Icon(
                            isGood ? Icons.check : Icons.close,
                            size: 18,
                            color: isGood
                                ? AppColors.success
                                : AppColors.error,
                          )
                        : Icon(
                            Icons.remove,
                            size: 18,
                            color: AppColors.outlineVariant,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  String _dayAbbr(int weekday) {
    const abbrs = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return abbrs[weekday - 1];
  }
}
