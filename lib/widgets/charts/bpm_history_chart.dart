import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_colors.dart';

class BpmHistoryChart extends StatelessWidget {
  final List<BpmReading> readings;

  const BpmHistoryChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return _emptyState();
    }

    final spots = <FlSpot>[];
    final maxReadings = 20;
    final displayReadings = readings.length > maxReadings
        ? readings.sublist(readings.length - maxReadings)
        : readings;

    for (int i = 0; i < displayReadings.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayReadings[i].bpm.toDouble()));
    }

    final maxY = displayReadings
        .map((r) => r.bpm)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final minY = displayReadings
        .map((r) => r.bpm)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final yAxisMax = (maxY + 20).clamp(100.0, 200.0);
    final yAxisMin = (minY - 20).clamp(0.0, 80.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    );
                  },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        '${value.toInt()}',
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
                    reservedSize: 22,
                    interval: (displayReadings.length / 5).ceil().toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= displayReadings.length) {
                        return const SizedBox.shrink();
                      }
                      final reading = displayReadings[index];
                      final timeStr =
                          '${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 9,
                            color: ChartColors.onSurfaceVariant,
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
              maxX: (displayReadings.length - 1).toDouble(),
              minY: yAxisMin,
              maxY: yAxisMax,
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 100,
                    color: ChartColors.error.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                        fontSize: 9,
                        color: ChartColors.error.withValues(alpha: 0.6),
                      ),
                      labelResolver: (_) => 'Limite sup.',
                    ),
                  ),
                  HorizontalLine(
                    y: 60,
                    color: ChartColors.error.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                        fontSize: 9,
                        color: ChartColors.error.withValues(alpha: 0.6),
                      ),
                      labelResolver: (_) => 'Limite inf.',
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: ChartColors.error,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final bpm = spot.y.toInt();
                      final isAbnormal = bpm < 60 || bpm > 100;
                      return FlDotCirclePainter(
                        radius: isAbnormal ? 4 : 2.5,
                        color: isAbnormal
                            ? ChartColors.error
                            : ChartColors.tertiary,
                        strokeWidth: 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: ChartColors.error.withValues(alpha: 0.05),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final reading = displayReadings[index];
                      final timeStr =
                          '${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}';
                      final status = spot.y < 60
                          ? 'Baixo'
                          : spot.y > 100
                          ? 'Elevado'
                          : 'Normal';
                      final isAbnormalChart = spot.y < 60 || spot.y > 100;
                      return LineTooltipItem(
                        '$timeStr\n${spot.y.toInt()} BPM\n$status',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isAbnormalChart ? 13 : 11,
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
            _legendDot(ChartColors.tertiary),
            const SizedBox(width: 4),
            const Text(
              'Normal (60-100)',
              style: TextStyle(
                fontSize: 11,
                color: ChartColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            _legendDot(ChartColors.error),
            const SizedBox(width: 4),
            const Text(
              'Fora da faixa',
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
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 40, color: ChartColors.outline),
            SizedBox(height: 8),
            Text(
              'Nenhuma medição de BPM registrada',
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

class BpmReading {
  final int bpm;
  final DateTime time;

  BpmReading({required this.bpm, required this.time});
}
