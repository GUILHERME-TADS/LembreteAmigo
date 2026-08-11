import 'dart:math';
import '../models/effectiveness_metrics.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';

class EffectivenessService {
  EffectivenessService._();
  static final EffectivenessService _instance = EffectivenessService._();
  static EffectivenessService get instance => _instance;

  static const Map<String, double> _categoryWeights = {
    'medicacao': 0.40,
    'hidratacao': 0.25,
    'refeicoes': 0.25,
    'exercicio': 0.10,
  };

  static const Map<String, String> _categoryLabels = {
    'medicacao': 'Medicação',
    'hidratacao': 'Hidratação',
    'refeicoes': 'Refeições',
    'exercicio': 'Exercícios',
  };

  static const List<String> _dayNames = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  List<LembreteEvento> collapseOccurrences(Iterable<LembreteEvento> events) {
    final eventList = events.toList();
    final correctedEventIds = eventList
        .map((event) => event.corrigeEventoId)
        .whereType<String>()
        .toSet();
    final occurrences = <String, LembreteEvento>{};
    for (final event in eventList) {
      if (event.categoria == 'bem_estar') continue;
      if (event.corrigeEventoId != null ||
          correctedEventIds.contains(event.id)) {
        continue;
      }
      final date = event.registradoEm;
      final key =
          event.ocorrenciaChave ??
          '${event.lembreteId}_${date.year}-${date.month}-${date.day}';
      final current = occurrences[key];
      if (current == null ||
          _statusPriority(event.status) > _statusPriority(current.status) ||
          (_statusPriority(event.status) == _statusPriority(current.status) &&
              event.registradoEm.isAfter(current.registradoEm))) {
        occurrences[key] = event;
      }
    }
    return occurrences.values.toList()
      ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
  }

  int _statusPriority(LembreteStatus status) {
    if (status.isConcluido) return 5;
    if (status == LembreteStatus.precisaDeAjuda) return 4;
    if (status == LembreteStatus.perdido) return 3;
    if (status == LembreteStatus.adiado) return 2;
    return 1;
  }

  EffectivenessMetrics compute(List<LembreteEvento> eventos, {int days = 14}) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - days + 1);
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final periodEvents = collapseOccurrences(
      eventos.where(
        (e) =>
            e.registradoEm.isAfter(
              startDate.subtract(const Duration(seconds: 1)),
            ) &&
            e.registradoEm.isBefore(endDate) &&
            e.categoria != 'bem_estar',
      ),
    );

    final dailyTrend = _computeDailyTrend(periodEvents, days, startDate);

    final categoryBreakdown = _computeCategoryBreakdown(periodEvents);

    final categoryScores = <String, double>{};
    for (final cat in categoryBreakdown) {
      categoryScores[cat.category] = cat.score;
    }

    final overallScore = _computeOverallScore(categoryBreakdown);

    final completedEvents = periodEvents
        .where((e) => e.status.isConcluido)
        .length;
    final totalEvents = periodEvents.length;

    final collapsedEvents = collapseOccurrences(eventos);
    final currentStreak = _computeCurrentStreak(collapsedEvents, days);
    final bestStreak = _computeBestStreak(collapsedEvents);

    final dayOfWeekStats = _computeDayOfWeekStats(periodEvents);
    final bestDayOfWeek = dayOfWeekStats.entries.isNotEmpty
        ? dayOfWeekStats.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '--';
    final worstDayOfWeek = dayOfWeekStats.entries.isNotEmpty
        ? dayOfWeekStats.entries.reduce((a, b) => a.value < b.value ? a : b).key
        : '--';

    final trend = _computeTrend(dailyTrend);

    final recommendations = _generateRecommendations(
      categoryBreakdown,
      currentStreak,
      worstDayOfWeek,
      trend,
    );

    return EffectivenessMetrics(
      overallScore: overallScore,
      categoryScores: categoryScores,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalDaysAnalyzed: days,
      totalEvents: totalEvents,
      completedEvents: completedEvents,
      bestDayOfWeek: bestDayOfWeek,
      worstDayOfWeek: worstDayOfWeek,
      trend: trend,
      dailyTrend: dailyTrend,
      categoryBreakdown: categoryBreakdown,
      recommendations: recommendations,
    );
  }

  List<DailyEffectiveness> _computeDailyTrend(
    List<LembreteEvento> eventos,
    int days,
    DateTime startDate,
  ) {
    final trend = <DailyEffectiveness>[];
    for (int i = 0; i < days; i++) {
      final day = DateTime(startDate.year, startDate.month, startDate.day + i);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final dayEvents = eventos.where(
        (e) =>
            e.registradoEm.isAfter(day.subtract(const Duration(seconds: 1))) &&
            e.registradoEm.isBefore(dayEnd),
      );
      final total = dayEvents.length;
      final completed = dayEvents.where((e) => e.status.isConcluido).length;
      final score = total > 0 ? (completed / total) * 100.0 : -1.0;
      trend.add(
        DailyEffectiveness(
          date: day,
          score: score,
          total: total,
          completed: completed,
        ),
      );
    }
    return trend;
  }

  List<CategoryEffectiveness> _computeCategoryBreakdown(
    List<LembreteEvento> eventos,
  ) {
    final categories = <String, List<LembreteEvento>>{};
    for (final e in eventos) {
      categories.putIfAbsent(e.categoria, () => []).add(e);
    }
    return categories.entries.map((entry) {
      final total = entry.value.length;
      final completed = entry.value.where((e) => e.status.isConcluido).length;
      final score = total > 0 ? (completed / total) * 100.0 : 0.0;
      return CategoryEffectiveness(
        category: entry.key,
        score: score,
        total: total,
        completed: completed,
        label: _categoryLabels[entry.key] ?? entry.key,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  double _computeOverallScore(List<CategoryEffectiveness> breakdown) {
    double weightedSum = 0;
    double totalWeight = 0;
    for (final cat in breakdown) {
      final weight = _categoryWeights[cat.category] ?? 0.1;
      weightedSum += cat.score * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  int _computeCurrentStreak(List<LembreteEvento> eventos, int days) {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final dayEvents = eventos.where(
        (e) =>
            e.registradoEm.isAfter(
              dayStart.subtract(const Duration(seconds: 1)),
            ) &&
            e.registradoEm.isBefore(dayEnd),
      );
      final total = dayEvents.length;
      if (total == 0) {
        if (i == 0) continue;
        break;
      }
      final completed = dayEvents.where((e) => e.status.isConcluido).length;
      final rate = completed / total;
      if (rate >= 0.8) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeBestStreak(List<LembreteEvento> eventos) {
    int bestStreak = 0;
    int currentStreak = 0;
    final dates =
        eventos
            .map(
              (e) => DateTime(
                e.registradoEm.year,
                e.registradoEm.month,
                e.registradoEm.day,
              ),
            )
            .toSet()
            .toList()
          ..sort();
    DateTime? previousDate;
    for (int i = 0; i < dates.length; i++) {
      if (previousDate != null &&
          dates[i].difference(previousDate).inDays != 1) {
        currentStreak = 0;
      }
      final dateEvents = eventos.where(
        (e) =>
            e.registradoEm.year == dates[i].year &&
            e.registradoEm.month == dates[i].month &&
            e.registradoEm.day == dates[i].day,
      );
      final total = dateEvents.length;
      final completed = dateEvents.where((e) => e.status.isConcluido).length;
      if (total > 0 && (completed / total) >= 0.8) {
        currentStreak++;
        bestStreak = max(bestStreak, currentStreak);
      } else {
        currentStreak = 0;
      }
      previousDate = dates[i];
    }
    return bestStreak;
  }

  Map<String, double> _computeDayOfWeekStats(List<LembreteEvento> eventos) {
    final dayStats = <int, List<double>>{};
    for (final e in eventos) {
      final dow = e.registradoEm.weekday - 1;
      dayStats.putIfAbsent(dow, () => []).add(e.status.isConcluido ? 1.0 : 0.0);
    }
    final result = <String, double>{};
    for (final entry in dayStats.entries) {
      final scores = entry.value;
      result[_dayNames[entry.key]] =
          scores.fold(0.0, (a, b) => a + b) / scores.length * 100;
    }
    return result;
  }

  String _computeTrend(List<DailyEffectiveness> dailyTrend) {
    final validDays = dailyTrend.where((d) => d.score >= 0).toList();
    if (validDays.length < 3) return 'stable';
    final n = validDays.length;
    final indices = List.generate(n, (i) => i.toDouble());
    final scores = validDays.map((d) => d.score).toList();
    final sumX = indices.fold(0.0, (a, b) => a + b);
    final sumY = scores.fold(0.0, (a, b) => a + b);
    final sumXY = _zipSum(indices, scores, (x, y) => x * y);
    final sumX2 = indices.fold(0.0, (a, b) => a + b * b);
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    if (slope > 0.5) return 'improving';
    if (slope < -0.5) return 'declining';
    return 'stable';
  }

  List<String> _generateRecommendations(
    List<CategoryEffectiveness> breakdown,
    int currentStreak,
    String worstDay,
    String trend,
  ) {
    final recs = <String>[];
    final worst = breakdown.isNotEmpty ? breakdown.last : null;
    if (worst != null && worst.score < 70) {
      recs.add(
        'A categoria "${worst.label}" tem a menor adesão (${worst.score.toStringAsFixed(0)}%). '
        'Considere criar lembretes extras ou ajustar os horários.',
      );
    }
    if (currentStreak >= 5) {
      recs.add(
        'Excelente! O idoso mantém uma sequência de $currentStreak dias '
        'com alta adesão. Continue assim!',
      );
    }
    if (worstDay.isNotEmpty) {
      recs.add(
        'Aos $worstDay a adesão costuma ser menor. Que tal '
        'enviar uma mensagem de apoio nesse dia?',
      );
    }
    if (trend == 'declining') {
      recs.add(
        'A adesão está diminuindo nos últimos dias. '
        'Verifique se o idoso precisa de mais suporte.',
      );
    }
    if (recs.isEmpty) {
      recs.add('Tudo dentro do esperado. Continue monitorando!');
    }
    return recs;
  }

  double _zipSum(
    List<double> a,
    List<double> b,
    double Function(double, double) fn,
  ) {
    double result = 0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      result += fn(a[i], b[i]);
    }
    return result;
  }
}
