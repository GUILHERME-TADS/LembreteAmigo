import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';

/// Serviço para gerar e compartilhar Relatório Clínico de Adesão para médicos em PDF
class MedicalReportPdfService {
  MedicalReportPdfService._();
  static final MedicalReportPdfService instance = MedicalReportPdfService._();

  Future<File> generateReportPdf({
    required String elderlyName,
    required String supervisorName,
    required List<Lembrete> medications,
    required List<LembreteEvento> recentEvents,
    double overallAdherence = 1.0,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final generatedAt = dateFormat.format(DateTime.now());

    final completedCount = recentEvents.where((e) => e.status.isConcluido).length;
    final missedCount = recentEvents.where((e) => !e.status.isConcluido).length;
    final totalEvents = recentEvents.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Cabeçalho Oficial
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Lembrete Amigo - Relatório Clínico',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Acompanhamento de Rotina e Adesão Farmacológica',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Gerado em: $generatedAt',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.indigo900),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
          pw.SizedBox(height: 12),

          // Dados do Paciente e Cuidador
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PACIENTE / IDOSO(A):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text(elderlyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RESPONSÁVEL / CUIDADOR:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text(supervisorName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ADESÃO GERAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('${(overallAdherence * 100).toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Tabela de Prescrições e Medicamentos em Uso
          pw.Text(
            '1. Prescrições e Medicamentos Cadastrados',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Medicamento', 'Horário', 'Dose', 'Frequência', 'Instruções Clínicas'],
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            data: medications.map((m) => [
              m.titulo,
              m.horarioFormatado,
              m.medicamentoDose ?? '1 un.',
              m.repeteTodosOsDias ? 'Diário' : m.recorrencia,
              m.medicamentoInstrucoes ?? '-',
            ]).toList(),
          ),
          pw.SizedBox(height: 18),

          // Resumo Estatístico do Período
          pw.Text(
            '2. Resumo de Execução e Tomadas',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    children: [
                      pw.Text('Doses Confirmadas', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900)),
                      pw.Text('$completedCount', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    children: [
                      pw.Text('Doses Perdidas / Atrasadas', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900)),
                      pw.Text('$missedCount', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    children: [
                      pw.Text('Total de Ocorrências', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900)),
                      pw.Text('$totalEvents', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Campo de Assinatura e Parecer do Médico
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text('Assinatura do Cuidador Responsável', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text('Carimbo e CRM do Médico(a)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final sanitizedName = elderlyName.replaceAll(' ', '_').toLowerCase();
    final file = File('${output.path}/relatorio_clinico_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> shareReport({
    required String elderlyName,
    required String supervisorName,
    required List<Lembrete> medications,
    required List<LembreteEvento> recentEvents,
    double overallAdherence = 1.0,
  }) async {
    final pdfFile = await generateReportPdf(
      elderlyName: elderlyName,
      supervisorName: supervisorName,
      medications: medications,
      recentEvents: recentEvents,
      overallAdherence: overallAdherence,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: 'Relatório Clínico de Adesão Farmacológica - $elderlyName',
        subject: 'Relatório Médico Lembrete Amigo',
        files: [XFile(pdfFile.path)],
      ),
    );
  }
}
