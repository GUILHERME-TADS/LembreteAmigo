import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_chart/fl_chart.dart';

import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/effectiveness_service.dart';
import '../services/session_role_service.dart';
import '../theme/app_theme.dart';

import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/charts/adherence_trend_chart.dart';
import '../widgets/charts/weekly_comparison_chart.dart';

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({super.key});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  bool _loadingData = false;
  String _idosoName = 'Idoso';
  int _medicacaoPct = 0;
  int _refeicoesPct = 0;
  int _exercicioPct = 0;
  int _hidratacaoPct = 0;
  int _geralPct = 0;
  int _weeklyTotal = 0;
  int _weeklyDone = 0;
  int _weeklyMissed = 0;
  String _weeklyHumanSummary =
      'Ainda nao ha dados suficientes para resumir a semana.';
  String _weeklyAttention =
      'Cadastre e acompanhe os lembretes para criar uma linha de cuidado.';

  @override
  void initState() {
    super.initState();
    LembreteService.instance.eventosNotifier.addListener(_onEventsChanged);
    _loadData();
  }

  @override
  void dispose() {
    LembreteService.instance.eventosNotifier.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() {
    if (!_loadingData) _loadData();
  }

  Future<void> _loadData() async {
    if (_loadingData) return;
    _loadingData = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();
      try {
        final doc = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();
        if (doc.exists) {
          _idosoName = doc.data()?['nome'] ?? 'Idoso';
        }
      } catch (_) {
        final profileJson = prefs.getString('idoso_perfil');
        if (profileJson != null) {
          try {
            final profile = jsonDecode(profileJson) as Map<String, dynamic>;
            _idosoName = profile['nome'] as String? ?? 'Idoso';
          } catch (_) {
            _idosoName = 'Idoso';
          }
        }
      }

      await LembreteService.instance.carregar();
      final eventos = LembreteService.instance.eventos;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthlyOccurrences = EffectivenessService.instance
          .collapseOccurrences(
        eventos.where((evento) => !evento.registradoEm.isBefore(monthStart)),
      );

      int getPctForCategory(String category) {
        final items = monthlyOccurrences
            .where((evento) => evento.categoria == category)
            .toList();
        if (items.isEmpty) return 0;
        final completed = items.where((evento) => evento.status.isConcluido).length;
        return ((completed / items.length) * 100).round();
      }

      final weekStart = DateTime.now().subtract(const Duration(days: 6));
      final weekStartDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final routineEvents = EffectivenessService.instance.collapseOccurrences(
        eventos.where(
          (evento) => !evento.registradoEm.isBefore(weekStartDate),
        ),
      );
      final completedCount = routineEvents
          .where((evento) => evento.status.isConcluido)
          .length;
      final missedCount = routineEvents
          .where((evento) => !evento.status.isConcluido)
          .length;
      final weeklyPct = routineEvents.isEmpty
          ? 0
          : ((completedCount / routineEvents.length) * 100).round();

      if (!mounted) return;
      setState(() {
        _medicacaoPct = getPctForCategory('medicacao');
        _refeicoesPct = getPctForCategory('refeicoes');
        _exercicioPct = getPctForCategory('exercicio');
        _hidratacaoPct = getPctForCategory('hidratacao');
        _geralPct = monthlyOccurrences.isEmpty
            ? 0
            : ((monthlyOccurrences
                            .where((evento) => evento.status.isConcluido)
                            .length /
                        monthlyOccurrences.length) *
                    100)
                  .round();
        _weeklyTotal = routineEvents.length;
        _weeklyDone = completedCount;
        _weeklyMissed = missedCount;
        _weeklyHumanSummary = _buildHumanSummary(
          weeklyPct,
          routineEvents.length,
          completedCount,
          missedCount,
        );
        _weeklyAttention = _buildAttentionSummary(
          weeklyPct,
          missedCount,
        );
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados de relatorios: $e');
    } finally {
      _loadingData = false;
    }
  }

  Future<void> _exportarRelatorioPDF() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final robotoFont = pw.Font.ttf(fontData);
      final pdfTheme = pw.ThemeData.withFont(base: robotoFont, bold: robotoFont);

      final pdf = pw.Document();
      final weeklyPct = _weeklyTotal == 0
          ? 0
          : ((_weeklyDone / _weeklyTotal) * 100).round();

      pdf.addPage(
        pw.Page(
          theme: pdfTheme,
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RELATORIO FAMILIAR - LEMBRETE AMIGO',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text('Paciente: $_idosoName'),
                  pw.Text(
                    'Gerado em: ${DateTime.now().toIso8601String().substring(0, 10)}',
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'RESUMO DA SEMANA',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Divider(),
                  pw.Bullet(text: 'Adesao semanal: $weeklyPct%'),
                  pw.Bullet(text: 'Atividades registradas: $_weeklyTotal'),
                  pw.Bullet(text: 'Atividades concluidas: $_weeklyDone'),
                  pw.Bullet(text: 'Atividades nao feitas: $_weeklyMissed'),
                  pw.Bullet(text: 'Resumo familiar: $_weeklyHumanSummary'),
                  pw.Bullet(text: 'Ponto de atencao: $_weeklyAttention'),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'ADERENCIA POR CATEGORIA',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Divider(),
                  pw.Bullet(text: 'Medicamentos: $_medicacaoPct%'),
                  pw.Bullet(text: 'Refeicoes: $_refeicoesPct%'),
                  pw.Bullet(text: 'Exercicios: $_exercicioPct%'),
                  pw.Bullet(text: 'Hidratacao: $_hidratacaoPct%'),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Desempenho geral: $_geralPct%',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/relatorio_familiar_$_idosoName.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Relatorio familiar de saude e rotina de $_idosoName',
        subject: 'Relatorio Familiar - Lembrete Amigo',
      );
    } catch (e) {
      debugPrint('Erro ao exportar PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao exportar PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.history,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildExportButton(),
                    const SizedBox(height: 24),
                    _buildWeeklyFamilySummary(),
                    const SizedBox(height: 16),
                    _buildAdherenceBreakdown(),
                    const SizedBox(height: 16),
                    _buildRadialChart(),
                    const SizedBox(height: 16),
                    _buildReportCharts(),
                    const SizedBox(height: 24),
                  ],
                ),
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
              'Lembrete Amigo',
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relatorios Familiares',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Resumo semanal e mensal de saude de $_idosoName',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _exportarRelatorioPDF,
        icon: const Icon(Icons.ios_share),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'COMPARTILHAR PDF COM A FAMILIA',
            maxLines: 1,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyFamilySummary() {
    final pct = _weeklyTotal == 0
        ? 0
        : ((_weeklyDone / _weeklyTotal) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.family_restroom, color: AppColors.primary, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resumo da Semana',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _weeklyMetric('Adesao', '$pct%'),
              const SizedBox(width: 10),
              _weeklyMetric('Feitos', '$_weeklyDone/$_weeklyTotal'),
              const SizedBox(width: 10),
              _weeklyMetric('Nao feitos', '$_weeklyMissed'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _weeklyHumanSummary,
            style: const TextStyle(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _weeklyAttention,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _weeklyMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildHumanSummary(int pct, int total, int done, int missed) {
    if (total == 0) {
      return 'Nesta semana ainda nao houve registros suficientes da rotina.';
    }
    if (pct >= 85 && missed == 0) {
      return '$_idosoName teve uma semana estavel, com $pct% da rotina concluida.';
    }
    if (pct >= 60) {
      return '$_idosoName concluiu $done de $total atividades, mas alguns horarios precisam de acompanhamento.';
    }
    return 'A semana exige atencao: apenas $done de $total atividades foram confirmadas.';
  }

  String _buildAttentionSummary(int pct, int missed) {
    if (missed >= 3) {
      return 'Houve $missed atividades nao feitas. Vale revisar horarios, dificuldade de uso ou necessidade de apoio presencial.';
    }
    if (pct >= 85) {
      return 'Sem ponto critico aparente nesta semana.';
    }
    return 'Acompanhe os proximos dias para entender se os atrasos foram pontuais ou recorrentes.';
  }

  Widget _buildAdherenceBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aderencia por Categoria',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryFixed,
            ),
          ),
          const SizedBox(height: 20),
          _breakdownRow(
            'Medicamentos',
            _medicacaoPct,
            AppColors.tertiaryFixedDim,
          ),
          const SizedBox(height: 14),
          _breakdownRow('Refeicoes', _refeicoesPct, AppColors.secondaryFixed),
          const SizedBox(height: 14),
          _breakdownRow(
            'Exercicios',
            _exercicioPct,
            AppColors.onTertiaryContainer,
          ),
          const SizedBox(height: 14),
          _breakdownRow(
            'Hidratacao',
            _hidratacaoPct,
            AppColors.voiceFeedbackBlue,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, int percent, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.primaryFixed,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryFixed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.primary.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildRadialChart() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final occurrences = EffectivenessService.instance.collapseOccurrences(
      LembreteService.instance.eventos.where(
        (evento) => !evento.registradoEm.isBefore(monthStart),
      ),
    );
    final total = occurrences.length;
    final completed = occurrences.where((e) => e.status.isConcluido).length;
    final pending = total - completed;

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        color: AppColors.tertiaryFixed,
        value: completed.toDouble(),
        title: completed > 0 ? '$completed' : '',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      if (pending > 0)
        PieChartSectionData(
          color: AppColors.surfaceContainerHigh,
          value: pending.toDouble(),
          title: '$pending',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Text(
            'Desempenho Geral',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: total == 0
                      ? const Center(
                          child: Text(
                            'Sem ocorrências neste mês',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _donutLegend(
                        AppColors.tertiaryFixed,
                        'Concluídos',
                        '$completed',
                      ),
                      const SizedBox(height: 12),
                      _donutLegend(
                        AppColors.surfaceContainerHigh,
                        'Não concluídos',
                        '$pending',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$_geralPct%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _donutLegend(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCharts() {
    final now = DateTime.now();
    final eventos = EffectivenessService.instance.collapseOccurrences(
      LembreteService.instance.eventos,
    );

    final dailyAdherence = <DateTime, double>{};
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final dayEvents = eventos.where((e) =>
          !e.registradoEm.isBefore(day) &&
          !e.registradoEm.isAfter(dayEnd));
      final total = dayEvents.length;
      if (total == 0) {
        dailyAdherence[day] = -1;
      } else {
        final completed = dayEvents.where((e) => e.status.isConcluido).length;
        dailyAdherence[day] = (completed / total * 100);
      }
    }

    final weekStart = DateTime(now.year, now.month, now.day - 6);
    final twoWeeksAgo = DateTime(now.year, now.month, now.day - 13);

    final currentWeekEvents = eventos.where((e) =>
        !e.registradoEm.isBefore(weekStart) &&
        !e.registradoEm.isAfter(now) &&
        e.categoria != 'bem_estar');
    final currentTotal = currentWeekEvents.length;
    final currentDone =
        currentWeekEvents.where((e) => e.status.isConcluido).length;

    final previousWeekEvents = eventos.where((e) =>
        !e.registradoEm.isBefore(twoWeeksAgo) &&
        e.registradoEm.isBefore(weekStart) &&
        e.categoria != 'bem_estar');
    final previousTotal = previousWeekEvents.length;
    final previousDone =
        previousWeekEvents.where((e) => e.status.isConcluido).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tendência de Adesão',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              AdherenceTrendChart(
                dailyAdherence: dailyAdherence,
                daysToShow: 14,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comparativo Semanal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              WeeklyComparisonChart(
                currentWeekCompleted: currentDone,
                currentWeekTotal: currentTotal,
                previousWeekCompleted: previousDone,
                previousWeekTotal: previousTotal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
