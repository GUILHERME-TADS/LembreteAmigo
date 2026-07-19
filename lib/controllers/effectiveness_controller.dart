import 'package:flutter/foundation.dart';
import '../models/effectiveness_metrics.dart';
import '../services/effectiveness_service.dart';
import '../services/lembrete_service.dart';

class EffectivenessController {
  EffectivenessController() {
    LembreteService.instance.eventosNotifier.addListener(_onEventsChanged);
  }

  EffectivenessMetrics? _metrics;
  int _selectedDays = 14;

  final ValueNotifier<EffectivenessMetrics?> metricsNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<int> selectedDaysNotifier = ValueNotifier(14);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  EffectivenessMetrics? get metrics => _metrics;
  int get selectedDays => _selectedDays;

  void _onEventsChanged() {
    final eventos = LembreteService.instance.eventos;
    _metrics = EffectivenessService.instance.compute(
      eventos,
      days: _selectedDays,
    );
    metricsNotifier.value = _metrics;
  }

  Future<void> load({int? days}) async {
    if (days != null) {
      _selectedDays = days;
      selectedDaysNotifier.value = days;
    }
    isLoadingNotifier.value = true;
    try {
      await LembreteService.instance.carregar();
      final eventos = LembreteService.instance.eventos;
      _metrics = EffectivenessService.instance.compute(
        eventos,
        days: _selectedDays,
      );
      metricsNotifier.value = _metrics;
    } catch (error) {
      debugPrint('Erro ao calcular efetividade: $error');
      metricsNotifier.value = null;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  void setDays(int days) {
    if (days != _selectedDays) {
      load(days: days);
    }
  }

  void dispose() {
    LembreteService.instance.eventosNotifier.removeListener(_onEventsChanged);
    metricsNotifier.dispose();
    selectedDaysNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
