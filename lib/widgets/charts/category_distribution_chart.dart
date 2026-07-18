import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_colors.dart';

class CategoryDistributionChart extends StatelessWidget {
  final Map<String, int> completedByCategory;
  final Map<String, int> totalByCategory;

  const CategoryDistributionChart({
    super.key,
    required this.completedByCategory,
    required this.totalByCategory,
  });

  static const _categoryColors = {
    'medicacao': Color(0xFFEF5350),
    'refeicao': Color(0xFFFFB74D),
    'refeicoes': Color(0xFFFFB74D),
    'exercicio': Color(0xFF66BB6A),
    'agua': Color(0xFF42A5F5),
    'hidratacao': Color(0xFF42A5F5),
    'bem_estar': Color(0xFFAB47BC),
  };

  static const _categoryLabels = {
    'medicacao': 'Medicação',
    'refeicoes': 'Refeições',
    'exercicio': 'Exercício',
    'hidratacao': 'Hidratação',
    'bem_estar': 'Bem-estar',
  };

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];
    final total = totalByCategory.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return _emptyState();
    }

    for (final entry in totalByCategory.entries) {
      final completed = completedByCategory[entry.key] ?? 0;
      final totalCount = entry.value;
      if (totalCount == 0) continue;
      final pct = (completed / totalCount * 100).round();
      final color = _categoryColors[entry.key] ?? Colors.grey;
      final label = _categoryLabels[entry.key] ?? entry.key;

      sections.add(PieChartSectionData(
        color: color,
        value: totalCount.toDouble(),
        title: '$pct%',
        radius: 45,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ChartColors.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '$completed/$totalCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ChartColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 35,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: legendItems,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return const SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 40, color: ChartColors.outline),
            SizedBox(height: 8),
            Text(
              'Nenhum lembrete cadastrado',
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
}
