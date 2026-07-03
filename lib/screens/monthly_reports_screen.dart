import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../theme/app_theme.dart';
import '../widgets/me_explica_button.dart';
import '../widgets/supervisor_bottom_nav.dart';

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({super.key});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  String _idosoName = 'Idoso';
  int _medicacaoPct = 0;
  int _refeicoesPct = 0;
  int _exercicioPct = 0;
  int _hidratacaoPct = 0;
  int _geralPct = 0;
  int _weeklyTotal = 0;
  int _weeklyDone = 0;
  int _weeklyMissed = 0;
  int? _lastBpm;
  String _weeklyWelfare = 'Sem check-in registrado nesta semana.';
  String _weeklyHumanSummary =
      'Ainda nao ha dados suficientes para resumir a semana.';
  String _weeklyAttention =
      'Cadastre e acompanhe os lembretes para criar uma linha de cuidado.';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId =
          prefs.getString('selected_idoso_id') ??
          prefs.getString('paired_idoso_id');
      if (idosoId != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .get();
          if (doc.exists) {
            _idosoName = doc.data()?['nome'] ?? 'Idoso';
          }
        } catch (_) {
          final json = prefs.getString('idoso_perfil');
          if (json != null && json.contains('nome')) {
            _idosoName = 'Idoso';
          }
        }
      }

      await LembreteService.instance.carregar();
      final lembretes = LembreteService.instance.lembretes;
      final eventos = LembreteService.instance.eventos;
      final lastBpm = prefs.getInt('last_bpm_value');

      int getPctForCategory(String category) {
        final items = lembretes.where((l) => l.categoria == category).toList();
        if (items.isEmpty) return 0;
        final completed = items.where((l) => l.concluido).length;
        return ((completed / items.length) * 100).round();
      }

      final weekStart = DateTime.now().subtract(const Duration(days: 6));
      final weekStartDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final weeklyEvents = eventos
          .where((evento) => !evento.registradoEm.isBefore(weekStartDate))
          .toList();
      final routineEvents = weeklyEvents
          .where((evento) => evento.categoria != 'bem_estar')
          .toList();
      final welfareEvents =
          weeklyEvents
              .where((evento) => evento.categoria == 'bem_estar')
              .toList()
            ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
      final completedCount = routineEvents
          .where((evento) => evento.status.isConcluido)
          .length;
      final missedCount = routineEvents
          .where((evento) => evento.status == LembreteStatus.perdido)
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
        _geralPct = lembretes.isEmpty
            ? 0
            : ((lembretes.where((l) => l.concluido).length / lembretes.length) *
                      100)
                  .round();
        _weeklyTotal = routineEvents.length;
        _weeklyDone = completedCount;
        _weeklyMissed = missedCount;
        _lastBpm = lastBpm;
        _weeklyWelfare = welfareEvents.isNotEmpty
            ? welfareEvents.first.observacao ?? 'Check-in registrado.'
            : 'Sem check-in registrado nesta semana.';
        _weeklyHumanSummary = _buildHumanSummary(
          weeklyPct,
          routineEvents.length,
          completedCount,
          missedCount,
        );
        _weeklyAttention = _buildAttentionSummary(
          weeklyPct,
          missedCount,
          lastBpm,
          _weeklyWelfare,
        );
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados de relatorios: $e');
    }
  }

  Future<void> _exportarRelatorioPDF() async {
    try {
      final pdf = pw.Document();
      final weeklyPct = _weeklyTotal == 0
          ? 0
          : ((_weeklyDone / _weeklyTotal) * 100).round();

      pdf.addPage(
        pw.Page(
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
                  pw.Bullet(
                    text:
                        'Ultimo batimento: ${_lastBpm != null ? '$_lastBpm BPM' : 'sem medicao'}',
                  ),
                  pw.Bullet(text: 'Bem-estar: $_weeklyWelfare'),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 12),
                    const MeExplicaButton(
                      textoExplicacao:
                          'Esta tela mostra um resumo da semana para a familia. Ela indica quantos lembretes foram feitos, o que ficou pendente, como foi o bem-estar e se existe algum ponto que merece atencao.',
                    ),
                    const SizedBox(height: 12),
                    _buildExportButton(),
                    const SizedBox(height: 24),
                    _buildWeeklyFamilySummary(),
                    const SizedBox(height: 16),
                    _buildAdherenceBreakdown(),
                    const SizedBox(height: 16),
                    _buildRadialChart(),
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
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          ),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
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
        label: const Text(
          'COMPARTILHAR PDF COM A FAMILIA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
              Text(
                'Resumo da Semana',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
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
          const SizedBox(height: 14),
          Text(
            _lastBpm != null
                ? 'Ultimo batimento medido: $_lastBpm BPM'
                : 'Sem batimento medido nesta semana.',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _weeklyWelfare,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              color: AppColors.onSurfaceVariant,
            ),
          ),
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

  String _buildAttentionSummary(int pct, int missed, int? bpm, String welfare) {
    if (missed >= 3) {
      return 'Houve $missed atividades nao feitas. Vale revisar horarios, dificuldade de uso ou necessidade de apoio presencial.';
    }
    if (bpm != null && (bpm < 60 || bpm > 100)) {
      return 'O ultimo batimento ficou fora da faixa de repouso usada pelo app. Acompanhe novas medicoes.';
    }
    if (!welfare.startsWith('Sem check-in')) {
      return 'Ultimo check-in de bem-estar: $welfare';
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.primaryFixed,
              ),
            ),
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
          Text(
            '$_geralPct%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: AppColors.onTertiaryContainer,
            ),
          ),
          const Text(
            'Baseado nos lembretes cadastrados',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
