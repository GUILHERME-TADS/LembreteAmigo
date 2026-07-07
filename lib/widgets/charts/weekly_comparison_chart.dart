import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_colors.dart';

class WeeklyComparisonChart extends StatelessWidget {
  final int currentWeekCompleted;
  final int currentWeekTotal;
  final int previousWeekCompleted;
  final int previousWeekTotal;

  const WeeklyComparisonChart({
    super.key,
    required this.currentWeekCompleted,
    required this.currentWeekTotal,
    required this.previousWeekCompleted,
    required this.previousWeekTotal,
  });

  @override
  Widget build(BuildContext context) {
    final currentPct = currentWeekTotal > 0
        ? (currentWeekCompleted / currentWeekTotal * 100).round()
        : 0;
    final previousPct = previousWeekTotal > 0
        ? (previousWeekCompleted / previousWeekTotal * 100).round()
        : 0;

    if (currentWeekTotal == 0 && previousWeekTotal == 0) {
      return _emptyState();
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final week = groupIndex == 0 ? 'Semana passada' : 'Esta semana';
                    final pct = rod.toY.toInt();
                    return BarTooltipItem(
                      '$week\n$pct%',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: ChartColors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Semana\npassada',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: ChartColors.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Esta\nsemana',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ChartColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              barGroups: [
                _makeBarGroup(0, previousPct.toDouble(), ChartColors.outline),
                _makeBarGroup(1, currentPct.toDouble(), ChartColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(ChartColors.outline),
            const SizedBox(width: 4),
            const Text(
              'Semana passada',
              style: TextStyle(
                fontSize: 11,
                color: ChartColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            _legendDot(ChartColors.primary),
            const SizedBox(width: 4),
            const Text(
              'Esta semana',
              style: TextStyle(
                fontSize: 11,
                color: ChartColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: Colors.grey.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 40, color: ChartColors.outline),
            SizedBox(height: 8),
            Text(
              'Compare a adesão entre semanas',
              style: TextStyle(
                fontSize: 14,
                color: ChartColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
