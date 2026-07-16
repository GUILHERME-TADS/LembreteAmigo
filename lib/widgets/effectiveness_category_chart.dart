import 'package:flutter/material.dart';
import '../models/effectiveness_metrics.dart';

class EffectivenessCategoryChart extends StatelessWidget {
  final List<CategoryEffectiveness> categories;

  const EffectivenessCategoryChart({super.key, required this.categories});

  Color _colorForScore(double score) {
    if (score >= 90) return const Color(0xFF2E7D32);
    if (score >= 70) return const Color(0xFFF57F17);
    return const Color(0xFFC62828);
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'medicacao':
        return Icons.medication;
      case 'hidratacao':
        return Icons.water_drop;
      case 'refeicoes':
        return Icons.restaurant;
      case 'exercicio':
        return Icons.directions_walk;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POR CATEGORIA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...categories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(_iconForCategory(cat.category), size: 20,
                  color: const Color(0xFF475569)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(
                  cat.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cat.score / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation(
                      _colorForScore(cat.score),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${cat.score.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _colorForScore(cat.score),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
