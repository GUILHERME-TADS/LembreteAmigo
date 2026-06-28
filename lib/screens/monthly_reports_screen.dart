import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/lembrete_service.dart';

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({super.key});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  String _idosoName = 'Maria';
  int _medicacaoPct = 95;
  int _refeicoesPct = 92;
  int _exercicioPct = 85;
  int _hidratacaoPct = 100;
  int _geralPct = 90;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('selected_idoso_id') ?? prefs.getString('paired_idoso_id');
      if (idosoId != null) {
        final doc = await FirebaseFirestore.instance.collection('idosos').doc(idosoId).get();
        if (doc.exists && mounted) {
          setState(() {
            _idosoName = doc.data()?['nome'] ?? 'Maria';
          });
        }
      }

      await LembreteService.instance.carregar();
      final lembretes = LembreteService.instance.lembretes;

      if (lembretes.isNotEmpty) {
        int getPctForCategory(String category, int defaultPct) {
          final items = lembretes.where((l) => l.categoria == category).toList();
          if (items.isEmpty) return defaultPct;
          final completed = items.where((l) => l.concluido).length;
          return ((completed / items.length) * 100).toInt();
        }

        final med = getPctForCategory('medicacao', 95);
        final ref = getPctForCategory('refeicoes', 92);
        final exe = getPctForCategory('exercicio', 85);
        final hid = getPctForCategory('hidratacao', 100);

        final totalCompleted = lembretes.where((l) => l.concluido).length;
        final geral = ((totalCompleted / lembretes.length) * 100).toInt();

        if (mounted) {
          setState(() {
            _medicacaoPct = med;
            _refeicoesPct = ref;
            _exercicioPct = exe;
            _hidratacaoPct = hid;
            _geralPct = geral;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de relatórios: $e');
    }
  }

  Future<void> _exportarRelatorioPDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('PRONTUARIO DE SAUDE - LEMBRETE AMIGO',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text('Paciente: $_idosoName', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Relatorio correspondente ao mes atual.', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 32),
                  pw.Text('INDICES DE ADESÃO:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  pw.Bullet(text: 'Medicamentos recomendados: $_medicacaoPct% cumpridos'),
                  pw.Bullet(text: 'Refeicoes no horario: $_refeicoesPct% cumpridos'),
                  pw.Bullet(text: 'Exercicios fisicos: $_exercicioPct% cumpridos'),
                  pw.Bullet(text: 'Metas de Hidratacao: $_hidratacaoPct% cumpridas'),
                  pw.SizedBox(height: 32),
                  pw.Text('DESEMPENHO GERAL: $_geralPct%',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 100),
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      children: [
                        pw.Container(width: 250, height: 1, color: PdfColors.grey),
                        pw.SizedBox(height: 8),
                        pw.Text('Assinatura do Supervisor Responsavel', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/relatorio_saude_$_idosoName.pdf');
      await file.writeAsBytes(await pdf.save());

      final XFile xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text: 'Relatório de Adesão à Saúde do Idoso $_idosoName',
        subject: 'Prontuário Médico - Lembrete Amigo',
      );
    } catch (e) {
      debugPrint('Erro ao exportar PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')),
        );
      }
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildExportButton(),
                    const SizedBox(height: 24),
                    _buildBarChart(),
                    const SizedBox(height: 16),
                    _buildRadialChart(),
                    const SizedBox(height: 16),
                    _buildAiInsights(),
                    const SizedBox(height: 16),
                    _buildAdherenceBreakdown(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomNav(context),
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
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.person, size: 24, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final String mesAtual = '${meses[now.month - 1]} ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relatórios Mensais',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Resumo de desempenho e saúde de $_idosoName — $mesAtual',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _exportarRelatorioPDF,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text(
          'EXPORTAR PDF PARA MÉDICO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tarefas do Mês',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _legendDot(AppColors.onTertiaryContainer, 'Concluídas'),
              const SizedBox(width: 16),
              _legendDot(AppColors.error, 'Atrasadas'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barColumn('Semana 1', 85, 15),
                _barColumn('Semana 2', 92, 8),
                _barColumn('Semana 3', 70, 30),
                _barColumn('Semana 4 (Atual)', _geralPct, (100 - _geralPct).clamp(0, 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _barColumn(String label, int completed, int late) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 12,
                  height: (completed / 100) * 150,
                  decoration: const BoxDecoration(
                    color: AppColors.onTertiaryContainer,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 12,
                  height: (late / 100) * 150,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildRadialChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evolução da Saúde',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _RadialProgressPainter(progress: _geralPct / 100.0, color: AppColors.tertiaryContainer),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_geralPct%',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.onTertiaryContainer),
                      ),
                      const Text(
                        'GERAL',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aderência geral baseada no cumprimento de todas as atividades agendadas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsights() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primaryContainer, size: 28),
              SizedBox(width: 12),
              Text(
                'Insights da IA',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _insightCard(
            Icons.check_circle,
            AppColors.onTertiaryContainer,
            '$_idosoName tomou $_medicacaoPct% dos remédios este mês. Sua consistência matinal é incrível.',
          ),
          const SizedBox(height: 12),
          _insightCard(
            Icons.warning,
            AppColors.secondary,
            'Observamos que $_idosoName realizou $_exercicioPct% dos exercícios físicos recomendados.',
          ),
          const SizedBox(height: 12),
          _insightCard(
            Icons.lightbulb,
            AppColors.primaryContainer,
            'Sugestão: Aumentar a hidratação entre as 14h e 16h para manter a adesão de $_hidratacaoPct%.',
          ),
        ],
      ),
    );
  }

  Widget _insightCard(IconData icon, Color iconColor, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
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
            'Detalhamento de Aderência',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.primaryFixed),
          ),
          const SizedBox(height: 24),
          _breakdownRow('Medicamentos', _medicacaoPct, AppColors.tertiaryFixedDim),
          const SizedBox(height: 16),
          _breakdownRow('Refeições', _refeicoesPct, AppColors.secondaryFixed),
          const SizedBox(height: 16),
          _breakdownRow('Exercícios', _exercicioPct, AppColors.onTertiaryContainer),
          const SizedBox(height: 16),
          _breakdownRow('Hidratação', _hidratacaoPct, AppColors.voiceFeedbackBlue),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.primaryContainer, width: 1)),
            ),
            child: Text(
              '"$_idosoName demonstra excelente cooperação em rotinas diárias."',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.primaryFixed),
            ),
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
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.primaryFixed)),
            Text('$percent%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.primaryFixed)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent / 100,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/supervisor-dashboard'),
              child: _navItem(Icons.home, 'Início', false),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/all-reminders'),
              child: _navItem(Icons.notifications, 'Lembretes', false),
            ),
          ),
          Expanded(
            child: _navItem(Icons.analytics, 'Relatórios', true),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/supervisor-settings'),
              child: _navItem(Icons.person, 'Perfil', false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.secondaryContainer : null,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0.05,
              color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadialProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final bgPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, bgPaint);
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5 * 3.1416,
      2 * 3.1416 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) => oldDelegate.progress != progress;
}
