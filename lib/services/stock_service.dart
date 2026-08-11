import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/lembrete.dart';
import '../models/stock_movement.dart';
import '../utils/firebase_helper.dart';
import 'lembrete_service.dart';

class StockService {
  StockService._();
  static final StockService instance = StockService._();

  Stream<List<StockMovement>> watchMovements(
    String elderlyId, {
    String? reminderId,
  }) {
    if (!FirebaseHelper.isInitialized || elderlyId.isEmpty) {
      return Stream.value(const <StockMovement>[]);
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('estoque_movimentos')
        .where('idosoId', isEqualTo: elderlyId);
    if (reminderId != null && reminderId.isNotEmpty) {
      query = query.where('lembreteId', isEqualTo: reminderId);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(StockMovement.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<int> replenish({
    required Lembrete reminder,
    required int quantity,
    DateTime? expirationDate,
    String note = '',
  }) async {
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    final response = await FirebaseFunctions.instance
        .httpsCallable('replenishMedicationStock')
        .call({
          'reminderId': reminder.id,
          'requestId': requestId,
          'quantity': quantity,
          if (expirationDate != null)
            'expirationDate':
                '${expirationDate.year.toString().padLeft(4, '0')}-'
                '${expirationDate.month.toString().padLeft(2, '0')}-'
                '${expirationDate.day.toString().padLeft(2, '0')}',
          if (note.trim().isNotEmpty) 'note': note.trim(),
        });
    final data = Map<String, dynamic>.from(response.data as Map);
    await LembreteService.instance.carregar();
    return (data['remainingStock'] as num?)?.toInt() ??
        reminder.medicamentoEstoque ??
        0;
  }

  double estimatedDailyConsumption(Lembrete reminder) {
    final units = reminder.medicamentoUnidadesPorDose ?? 1;
    if (reminder.recorrenciaIntervalo || reminder.recorrencia == 'intervalo') {
      final interval = max(1, reminder.intervaloHoras ?? 4);
      return units * (24 / interval);
    }
    if (reminder.recorrenciaSemanal || reminder.recorrencia == 'semanal') {
      final days = reminder.diasSemana.isEmpty ? 1 : reminder.diasSemana.length;
      return units * days / 7;
    }
    if (reminder.recorrenciaMensal || reminder.recorrencia == 'mensal') {
      return units / 30;
    }
    return units;
  }

  int? estimatedDaysRemaining(Lembrete reminder) {
    final stock = reminder.medicamentoEstoque;
    if (stock == null) return null;
    final daily = estimatedDailyConsumption(reminder);
    if (daily <= 0) return null;
    return (stock / daily).floor();
  }
}
