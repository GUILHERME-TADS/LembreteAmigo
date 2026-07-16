import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/effectiveness_metrics.dart';
import 'package:lembretes_app/models/lembrete.dart';
import 'package:lembretes_app/models/lembrete_evento.dart';
import 'package:lembretes_app/services/effectiveness_service.dart';

void main() {
  group('EffectivenessService', () {
    late List<LembreteEvento> eventos;

    setUp(() {
      final now = DateTime(2026, 7, 9, 15, 0, 0);
      eventos = [
        LembreteEvento(
          id: '1',
          lembreteId: 'l1',
          titulo: 'Tomar Losartana',
          categoria: 'medicacao',
          status: LembreteStatus.concluido,
          registradoEm: DateTime(2026, 7, 9, 8, 0),
        ),
        LembreteEvento(
          id: '2',
          lembreteId: 'l1',
          titulo: 'Tomar Losartana',
          categoria: 'medicacao',
          status: LembreteStatus.concluido,
          registradoEm: DateTime(2026, 7, 8, 8, 0),
        ),
        LembreteEvento(
          id: '3',
          lembreteId: 'l2',
          titulo: 'Beber agua',
          categoria: 'hidratacao',
          status: LembreteStatus.pendente,
          registradoEm: DateTime(2026, 7, 9, 10, 0),
        ),
        LembreteEvento(
          id: '4',
          lembreteId: 'l3',
          titulo: 'Caminhar',
          categoria: 'exercicio',
          status: LembreteStatus.concluido,
          registradoEm: DateTime(2026, 7, 7, 9, 0),
        ),
        LembreteEvento(
          id: '5',
          lembreteId: 'l4',
          titulo: 'Cafe da manha',
          categoria: 'refeicoes',
          status: LembreteStatus.concluido,
          registradoEm: DateTime(2026, 7, 9, 7, 0),
        ),
        LembreteEvento(
          id: '6',
          lembreteId: 'l5',
          titulo: 'Almoco',
          categoria: 'refeicoes',
          status: LembreteStatus.perdido,
          registradoEm: DateTime(2026, 7, 9, 12, 0),
        ),
      ];
    });

    test('compute retorna métricas corretas', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result, isA<EffectivenessMetrics>());
      expect(result.totalDaysAnalyzed, 7);
      expect(result.totalEvents, 6);
      expect(result.completedEvents, 4);
    });

    test('compute calcula score geral ponderado', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.overallScore, greaterThan(0));
      expect(result.overallScore, lessThanOrEqualTo(100));
    });

    test('compute retorna scores por categoria', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.categoryScores, containsPair('medicacao', 100.0));
      expect(result.categoryScores, containsPair('hidratacao', 0.0));
      expect(result.categoryScores, containsPair('exercicio', 100.0));
    });

    test('compute retorna categoryBreakdown ordenado', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.categoryBreakdown.length, greaterThanOrEqualTo(1));
      for (int i = 0; i < result.categoryBreakdown.length - 1; i++) {
        expect(
          result.categoryBreakdown[i].score,
          greaterThanOrEqualTo(result.categoryBreakdown[i + 1].score),
        );
      }
    });

    test('compute retorna dailyTrend', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.dailyTrend.length, 7);
      expect(result.dailyTrend[0], isA<DailyEffectiveness>());
    });

    test('trend é stable quando não há dados suficientes', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(['improving', 'declining', 'stable'], contains(result.trend));
    });

    test('currentStreak conta dias consecutivos com >= 80%', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.currentStreak, greaterThanOrEqualTo(0));
    });

    test('bestStreak é maior ou igual a currentStreak', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.bestStreak, greaterThanOrEqualTo(result.currentStreak));
    });

    test('bestDayOfWeek e worstDayOfWeek são retornados', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.bestDayOfWeek, isNotEmpty);
      expect(result.worstDayOfWeek, isNotEmpty);
    });

    test('recommendations são geradas', () {
      final result = EffectivenessService.instance.compute(
        eventos,
        days: 7,
      );

      expect(result.recommendations, isNotEmpty);
    });

    test('retorna dados consistentes para lista vazia', () {
      final result = EffectivenessService.instance.compute([], days: 7);

      expect(result.totalEvents, 0);
      expect(result.completedEvents, 0);
      expect(result.overallScore, 0);
      expect(result.currentStreak, 0);
      expect(result.bestStreak, 0);
      expect(result.recommendations, isNotEmpty);
    });

    test('retorna completionRate igual a overallScore para dados uniformes', () {
      final now = DateTime.now();
      final completos = List.generate(10, (i) => LembreteEvento(
        id: 'c$i',
        lembreteId: 'l$i',
        titulo: 'Evento $i',
        categoria: 'medicacao',
        status: LembreteStatus.concluido,
        registradoEm: now.subtract(Duration(days: i ~/ 2)),
      ));

      final result = EffectivenessService.instance.compute(completos, days: 7);
      expect(result.completionRate, greaterThan(0));
    });
  });
}
