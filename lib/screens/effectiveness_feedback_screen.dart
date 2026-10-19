import 'package:flutter/material.dart';
import '../controllers/effectiveness_controller.dart';
import '../models/effectiveness_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/effectiveness_score_gauge.dart';
import '../widgets/effectiveness_category_chart.dart';
import '../widgets/effectiveness_streak_calendar.dart';
import '../widgets/effectiveness_trend_chart.dart';
import '../widgets/app_top_bar.dart';

class EffectivenessFeedbackScreen extends StatefulWidget {
  const EffectivenessFeedbackScreen({super.key});

  @override
  State<EffectivenessFeedbackScreen> createState() =>
      _EffectivenessFeedbackScreenState();
}

class _EffectivenessFeedbackScreenState
    extends State<EffectivenessFeedbackScreen> {
  final _controller = EffectivenessController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Efetividade'),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoadingNotifier,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ValueListenableBuilder<EffectivenessMetrics?>(
                    valueListenable: _controller.metricsNotifier,
                    builder: (context, metrics, _) {
                      if (metrics == null) {
                        return const Center(
                          child: Text('Nenhum dado disponível'),
                        );
                      }
                      return _buildContent(metrics);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildContent(EffectivenessMetrics metrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreCard(metrics),
          const SizedBox(height: 16),
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildCategoryCard(metrics.categoryBreakdown),
          const SizedBox(height: 16),
          _buildStreakCard(metrics),
          const SizedBox(height: 16),
          _buildTrendCard(metrics.dailyTrend, metrics.trend),
          const SizedBox(height: 16),
          _buildSummaryCard(metrics),
          const SizedBox(height: 16),
          _buildRecommendationsCard(metrics.recommendations),
        ],
      ),
    );
  }

  Widget _buildScoreCard(EffectivenessMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(child: EffectivenessScoreGauge(score: metrics.overallScore)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                Icons.event_note,
                '${metrics.totalDaysAnalyzed}',
                'Dias',
              ),
              _buildStatColumn(
                Icons.checklist,
                '${metrics.completedEvents}',
                'Ok',
              ),
              _buildStatColumn(
                Icons.pending_actions,
                '${metrics.totalEvents - metrics.completedEvents}',
                'Pendentes',
              ),
              _buildStatColumn(
                Icons.local_fire_department,
                '${metrics.currentStreak}',
                'Seguidas',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return ValueListenableBuilder<int>(
      valueListenable: _controller.selectedDaysNotifier,
      builder: (context, selected, _) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [7, 14, 30].map((days) {
              final isSelected = selected == days;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _controller.setDays(days),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$days dias',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(List<CategoryEffectiveness> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: EffectivenessCategoryChart(categories: categories),
    );
  }

  Widget _buildStreakCard(EffectivenessMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: EffectivenessStreakCalendar(
        currentStreak: metrics.currentStreak,
        bestStreak: metrics.bestStreak,
        dailyTrend: metrics.dailyTrend,
      ),
    );
  }

  Widget _buildTrendCard(List<DailyEffectiveness> dailyTrend, String trend) {
    final trendIcon = trend == 'improving'
        ? Icons.trending_up
        : trend == 'declining'
        ? Icons.trending_down
        : Icons.trending_flat;
    final trendColor = trend == 'improving'
        ? AppColors.success
        : trend == 'declining'
        ? AppColors.error
        : AppColors.warning;
    final trendLabel = trend == 'improving'
        ? 'Melhorando'
        : trend == 'declining'
        ? 'Diminuindo'
        : 'Estável';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trendIcon, color: trendColor, size: 22),
              const SizedBox(width: 6),
              Text(
                'TENDÊNCIA ($trendLabel)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EffectivenessTrendChart(dailyTrend: dailyTrend),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(EffectivenessMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMO',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Melhor dia',
            metrics.bestDayOfWeek,
            Icons.arrow_upward,
            AppColors.success,
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Dia de atenção',
            metrics.worstDayOfWeek,
            Icons.arrow_downward,
            AppColors.error,
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Total de eventos',
            '${metrics.totalEvents}',
            Icons.event_note,
            AppColors.info,
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Taxa de conclusão',
            '${metrics.completionRate.toStringAsFixed(1)}%',
            Icons.check_circle,
            AppColors.medicationsColor,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.info, size: 20),
              SizedBox(width: 6),
              Text(
                'RECOMENDAÇÕES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
