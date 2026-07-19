import 'package:flutter/material.dart';
import '../controllers/effectiveness_controller.dart';
import '../models/effectiveness_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/effectiveness_score_gauge.dart';
import '../widgets/effectiveness_category_chart.dart';
import '../widgets/effectiveness_streak_calendar.dart';
import '../widgets/effectiveness_trend_chart.dart';

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
            _buildTopBar(context),
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

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
          ),
          const Expanded(
            child: Text(
              'Efetividade',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(EffectivenessMetrics metrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          Center(
            child: EffectivenessScoreGauge(score: metrics.overallScore),
          ),
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
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
          ),
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
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$days dias',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
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
        ? const Color(0xFF2E7D32)
        : trend == 'declining'
            ? const Color(0xFFC62828)
            : const Color(0xFFF57F17);
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
          const Text(
            'RESUMO',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Melhor dia', metrics.bestDayOfWeek, Icons.arrow_upward,
              const Color(0xFF2E7D32)),
          const SizedBox(height: 6),
          _summaryRow('Dia de atenção', metrics.worstDayOfWeek,
              Icons.arrow_downward, const Color(0xFFC62828)),
          const SizedBox(height: 6),
          _summaryRow('Total de eventos', '${metrics.totalEvents}',
              Icons.event_note, const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          _summaryRow(
            'Taxa de conclusão',
            '${metrics.completionRate.toStringAsFixed(1)}%',
            Icons.check_circle,
            const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
            ),
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 6),
              Text(
                'RECOMENDAÇÕES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                )),
                Expanded(
                  child: Text(
                    rec,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
