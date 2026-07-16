import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/effectiveness_metrics.dart';

void main() {
  group('EffectivenessMetrics', () {
    test('cria instancia com valores corretos', () {
      final metrics = EffectivenessMetrics(
        overallScore: 85.5,
        categoryScores: {'medicacao': 100.0, 'hidratacao': 80.0},
        currentStreak: 5,
        bestStreak: 10,
        totalDaysAnalyzed: 14,
        totalEvents: 100,
        completedEvents: 85,
        bestDayOfWeek: 'Terça',
        worstDayOfWeek: 'Domingo',
        trend: 'improving',
        dailyTrend: [],
        categoryBreakdown: [],
        recommendations: ['Continue assim!'],
      );

      expect(metrics.overallScore, 85.5);
      expect(metrics.currentStreak, 5);
      expect(metrics.bestStreak, 10);
      expect(metrics.totalDaysAnalyzed, 14);
      expect(metrics.totalEvents, 100);
      expect(metrics.completedEvents, 85);
      expect(metrics.bestDayOfWeek, 'Terça');
      expect(metrics.worstDayOfWeek, 'Domingo');
      expect(metrics.trend, 'improving');
      expect(metrics.recommendations.length, 1);
    });

    test('completionRate calcula corretamente', () {
      final metrics = EffectivenessMetrics(
        overallScore: 75.0,
        categoryScores: {},
        currentStreak: 3,
        bestStreak: 7,
        totalDaysAnalyzed: 14,
        totalEvents: 40,
        completedEvents: 30,
        bestDayOfWeek: 'Segunda',
        worstDayOfWeek: 'Sexta',
        trend: 'stable',
        dailyTrend: [],
        categoryBreakdown: [],
        recommendations: [],
      );

      expect(metrics.completionRate, 75.0);
    });

    test('completionRate retorna 0 quando total é 0', () {
      final metrics = EffectivenessMetrics(
        overallScore: 0,
        categoryScores: {},
        currentStreak: 0,
        bestStreak: 0,
        totalDaysAnalyzed: 7,
        totalEvents: 0,
        completedEvents: 0,
        bestDayOfWeek: '',
        worstDayOfWeek: '',
        trend: 'stable',
        dailyTrend: [],
        categoryBreakdown: [],
        recommendations: [],
      );

      expect(metrics.completionRate, 0);
    });
  });

  group('DailyEffectiveness', () {
    test('cria instancia', () {
      final now = DateTime(2026, 7, 9);
      final daily = DailyEffectiveness(
        date: now,
        score: 90.0,
        total: 10,
        completed: 9,
      );

      expect(daily.date, now);
      expect(daily.score, 90.0);
      expect(daily.total, 10);
      expect(daily.completed, 9);
    });
  });

  group('CategoryEffectiveness', () {
    test('cria instancia', () {
      final cat = CategoryEffectiveness(
        category: 'medicacao',
        score: 100.0,
        total: 5,
        completed: 5,
        label: 'Medicação',
      );

      expect(cat.category, 'medicacao');
      expect(cat.score, 100.0);
      expect(cat.total, 5);
      expect(cat.completed, 5);
      expect(cat.label, 'Medicação');
    });
  });
}
