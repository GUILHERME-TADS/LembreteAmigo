import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_colors.dart';

class AdherenceTrendChart extends StatelessWidget {
  final Map<DateTime, double> dailyAdherence;
  final int daysToShow;

  const AdherenceTrendChart({
    super.key,
    required this.dailyAdherence,
    this.daysToShow = 14,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    double maxY = 100;
    double minY = 0;
    double lastValue = 0;

    for (int i = daysToShow - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final value = dailyAdherence[day] ?? -1;
      spots.add(FlSpot((daysToShow - 1 - i).toDouble(), value));
      if (value >= 0) {
        if (value > maxY) maxY = value;
        if (value < minY) minY = value;
        lastValue = value;
      }
    }

    if (spots.isEmpty || spots.every((s) => s.y < 0)) {
      return _emptyState();
    }

    final maxVal = 100.0;
    final minVal = minY > 0 ? 0.0 : minY;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
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
                    interval: 1,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= daysToShow) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(
                        now.year, now.month, now.day - (daysToShow - 1 - index),
                      );
                      final labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[day.weekday % 7],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: day.weekday == now.weekday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: day.weekday == now.weekday
                                ? ChartColors.primary
                                : ChartColors.onSurfaceVariant,
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
              minX: 0,
              maxX: (daysToShow - 1).toDouble(),
              minY: minVal.toDouble(),
              maxY: maxVal.toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots.where((s) => s.y >= 0).toList(),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: ChartColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: spot.y == lastValue ? 4 : 2.5,
                        color: ChartColors.primary,
                        strokeWidth: 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: ChartColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final day = DateTime(
                        now.year, now.month, now.day - (daysToShow - 1 - index),
                      );
                      final dateStr =
                          '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
                      final value = spot.y >= 0
                          ? '${spot.y.toInt()}%'
                          : 'Sem dados';
                      return LineTooltipItem(
                        '$dateStr\n$value',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(ChartColors.primary),
            const SizedBox(width: 4),
            const Text(
              'Adesão diária',
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

  Widget _emptyState() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 40, color: ChartColors.outline),
            SizedBox(height: 8),
            Text(
              'Dados insuficientes para o gráfico',
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
