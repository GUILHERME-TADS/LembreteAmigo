import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _themeKey = 'widget_theme';
  static const String _fontSizeKey = 'widget_font_size';

  final ValueNotifier<String> themeNotifier = ValueNotifier<String>('classic_blue');
  final ValueNotifier<String> fontSizeNotifier = ValueNotifier<String>('normal');

  Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey) ?? 'classic_blue';
      final fontSize = prefs.getString(_fontSizeKey) ?? 'normal';
      themeNotifier.value = theme;
      fontSizeNotifier.value = fontSize;
    } catch (e) {
      debugPrint('Erro ao carregar preferências do widget: $e');
    }
  }

  Future<void> setTheme(String theme) async {
    try {
      themeNotifier.value = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
      await HomeWidget.saveWidgetData<String>(_themeKey, theme);
      await atualizar();
    } catch (e) {
      debugPrint('Erro ao salvar tema do widget: $e');
    }
  }

  Future<void> setFontSize(String size) async {
    try {
      fontSizeNotifier.value = size;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontSizeKey, size);
      await HomeWidget.saveWidgetData<String>(_fontSizeKey, size);
      await atualizar();
    } catch (e) {
      debugPrint('Erro ao salvar tamanho de fonte do widget: $e');
    }
  }

  Future<void> atualizar() async {
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final ativosHoje = ReminderStateHelper.activeTodaySorted(
        LembreteService.instance.lembretes,
        now: now,
      );
      final proximos =
          ativosHoje
              .where(
                (l) =>
                    !l.concluido &&
                    l.status != LembreteStatus.perdido &&
                    l.status != LembreteStatus.precisaDeAjuda,
              )
              .map((l) {
                var hour = l.horarioHour;
                var minute = l.horarioMinute;
                if (l.recorrenciaIntervalo || l.recorrencia == 'intervalo') {
                  final intervalHours = (l.intervaloHoras ?? 4).clamp(1, 24);
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
              return (a.horarioHour * 60 + a.horarioMinute).compareTo(
                b.horarioHour * 60 + b.horarioMinute,
              );
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
      await HomeWidget.saveWidgetData<String>(_themeKey, themeNotifier.value);
      await HomeWidget.saveWidgetData<String>(_fontSizeKey, fontSizeNotifier.value);

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
