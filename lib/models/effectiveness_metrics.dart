class EffectivenessMetrics {
  final double overallScore;
  final Map<String, double> categoryScores;
  final int currentStreak;
  final int bestStreak;
  final int totalDaysAnalyzed;
  final int totalEvents;
  final int completedEvents;
  final String bestDayOfWeek;
  final String worstDayOfWeek;
  final String trend;
  final List<DailyEffectiveness> dailyTrend;
  final List<CategoryEffectiveness> categoryBreakdown;
  final List<String> recommendations;

  const EffectivenessMetrics({
    required this.overallScore,
    required this.categoryScores,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalDaysAnalyzed,
    required this.totalEvents,
    required this.completedEvents,
    required this.bestDayOfWeek,
    required this.worstDayOfWeek,
    required this.trend,
    required this.dailyTrend,
    required this.categoryBreakdown,
    required this.recommendations,
  });

  double get completionRate =>
      totalEvents > 0 ? (completedEvents / totalEvents) * 100 : 0;
}

class DailyEffectiveness {
  final DateTime date;
  final double score;
  final int total;
  final int completed;

  const DailyEffectiveness({
    required this.date,
    required this.score,
    required this.total,
    required this.completed,
  });
}

class CategoryEffectiveness {
  final String category;
  final double score;
  final int total;
  final int completed;
  final String label;

  const CategoryEffectiveness({
    required this.category,
    required this.score,
    required this.total,
    required this.completed,
    required this.label,
  });
}
