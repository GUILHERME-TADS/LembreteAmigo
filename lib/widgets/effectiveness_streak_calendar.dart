import 'package:flutter/material.dart';
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
            const Icon(Icons.local_fire_department,
                color: Color(0xFFFF6D00), size: 22),
            const SizedBox(width: 6),
            Text(
              '$currentStreak dias consecutivos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        if (bestStreak > currentStreak) ...[
          const SizedBox(height: 2),
          Text(
            'Recorde: $bestStreak dias',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
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
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                            : const Color(0xFFC62828).withValues(alpha: 0.1))
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: hasData
                        ? Icon(
                            isGood ? Icons.check : Icons.close,
                            size: 18,
                            color: isGood
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          )
                        : const Icon(Icons.remove, size: 18,
                            color: Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
