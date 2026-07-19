import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/lembrete.dart';
import '../models/widget_data.dart';
import 'lembrete_service.dart';
import 'session_role_service.dart';
import '../utils/reminder_state_helper.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String _widgetName = 'LembreteAmigoWidget';
  static const String _androidWidgetClass = 'LembreteAmigoWidgetProvider';
  static const String _dataKey = 'reminders';
  static const String _roleKey = 'widget_role';
  static const String _updatedAtKey = 'widget_updated_at';

  Future<void> atualizar() async {
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final ativosHoje = ReminderStateHelper.activeTodaySorted(
        LembreteService.instance.lembretes,
        now: now,
      );
      final proximos = ativosHoje
          .where((l) =>
              !l.concluido &&
              l.status != LembreteStatus.perdido &&
              l.status != LembreteStatus.precisaDeAjuda)
          .map((l) {
            var hour = l.horarioHour;
            var minute = l.horarioMinute;
            if (l.recorrenciaIntervalo || l.recorrencia == 'intervalo') {
              final intervalHours =
                  (l.intervaloHoras ?? 4).clamp(1, 24) as int;
              final intervalMinutes = intervalHours * 60;
              var occurrence = hour * 60 + minute;
              while (occurrence < nowMinutes && occurrence < 24 * 60) {
                occurrence += intervalMinutes;
              }
              if (occurrence >= 24 * 60) return null;
              hour = occurrence ~/ 60;
              minute = occurrence % 60;
            }
            final minutes = hour * 60 + minute;
            final diff = minutes - nowMinutes;
            final status = l.status == LembreteStatus.adiado
                ? 'adiado'
                : diff < -4
                    ? 'atrasado'
                    : diff <= 1
                        ? 'agora'
                        : 'proximo';
            return WidgetData(
              id: l.id,
              titulo: l.titulo,
              horarioHour: hour,
              horarioMinute: minute,
              categoria: l.categoria,
              status: status,
            );
          })
          .whereType<WidgetData>()
          .toList()
        ..sort((a, b) {
          int priority(WidgetData item) => switch (item.status) {
            'agora' => 0,
            'atrasado' => 1,
            'adiado' => 2,
            _ => 3,
          };
          final statusCompare = priority(a).compareTo(priority(b));
          if (statusCompare != 0) return statusCompare;
          return (a.horarioHour * 60 + a.horarioMinute)
              .compareTo(b.horarioHour * 60 + b.horarioMinute);
        });

      final pendentes = <WidgetData>[];
      for (final item in proximos) {
        pendentes.add(item);
        if (pendentes.length >= 3) break;
      }

      final json = jsonEncode(pendentes.map((w) => w.toJson()).toList());

      await HomeWidget.saveWidgetData<String>(_dataKey, json);
      await HomeWidget.saveWidgetData<String>(
        _roleKey,
        SessionRoleService.isSupervisor ? 'supervisor' : 'elderly',
      );
      await HomeWidget.saveWidgetData<String>(
        _updatedAtKey,
        now.toIso8601String(),
      );
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
