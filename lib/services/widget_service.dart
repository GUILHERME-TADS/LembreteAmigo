import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/lembrete.dart';
import '../models/widget_data.dart';
import 'lembrete_service.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _widgetName = 'LembreteAmigoWidget';
  static const String _androidWidgetClass = 'LembreteAmigoWidgetProvider';
  static const String _dataKey = 'reminders';

  Future<void> atualizar() async {
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final proximos = LembreteService.instance.lembretes
          .where((l) => !l.concluido && l.status != LembreteStatus.perdido)
          .toList()
        ..sort((a, b) {
          final aMinutes = a.horarioHour * 60 + a.horarioMinute;
          final bMinutes = b.horarioHour * 60 + b.horarioMinute;
          return aMinutes.compareTo(bMinutes);
        });

      final pendentes = <WidgetData>[];
      for (final l in proximos) {
        final lMinutes = l.horarioHour * 60 + l.horarioMinute;
        if (lMinutes < nowMinutes && l.recorrencia != 'intervalo') continue;
        pendentes.add(WidgetData(
          id: l.id,
          titulo: l.titulo,
          horarioHour: l.horarioHour,
          horarioMinute: l.horarioMinute,
          categoria: l.categoria,
        ));
        if (pendentes.length >= 3) break;
      }

      final json = jsonEncode(pendentes.map((w) => w.toJson()).toList());

      await HomeWidget.saveWidgetData<String>(_dataKey, json);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidWidgetClass,
        iOSName: _widgetName,
      );
    } catch (e) {
      // Widget update failed silently - no crash needed
    }
  }
}
