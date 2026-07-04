import 'package:flutter/material.dart';

class PeriodHelper {
  static String getPeriodLabel(int hour) {
    if (hour >= 6 && hour < 12) {
      return 'Manhã';
    } else if (hour >= 12 && hour < 18) {
      return 'Tarde';
    } else if (hour >= 18 && hour < 24) {
      return 'Noite';
    } else {
      return 'Madrugada';
    }
  }

  static IconData getPeriodIcon(int hour) {
    if (hour >= 6 && hour < 12) {
      return Icons.wb_sunny;
    } else if (hour >= 12 && hour < 18) {
      return Icons.wb_twilight;
    } else if (hour >= 18 && hour < 24) {
      return Icons.bedtime;
    } else {
      return Icons.nightlight_round;
    }
  }

  static Color getPeriodColor(int hour) {
    if (hour >= 6 && hour < 12) {
      return const Color(0xFFB57000); // Amber/Golden (contrast compliant)
    } else if (hour >= 12 && hour < 18) {
      return const Color(0xFFD45500); // Warm Orange
    } else if (hour >= 18 && hour < 24) {
      return const Color(0xFF2E3B84); // Indigo
    } else {
      return const Color(0xFF455A64); // Blue Grey
    }
  }

  static int? _parseHour(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.isNotEmpty) {
        return int.parse(parts[0].trim());
      }
    } catch (_) {}
    return null;
  }

  static String getPeriodLabelFromStr(String timeStr) {
    final hour = _parseHour(timeStr);
    if (hour == null) return 'Agendado';
    return getPeriodLabel(hour);
  }

  static IconData getPeriodIconFromStr(String timeStr) {
    final hour = _parseHour(timeStr);
    if (hour == null) return Icons.schedule;
    return getPeriodIcon(hour);
  }

  static Color getPeriodColorFromStr(String timeStr, Color fallback) {
    final hour = _parseHour(timeStr);
    if (hour == null) return fallback;
    return getPeriodColor(hour);
  }

  static String getSpokenTime(int hour, int minute) {
    if (hour == 0 && minute == 0) {
      return 'meia-noite';
    }
    if (hour == 12 && minute == 0) {
      return 'meio-dia';
    }

    String hourStr;
    if (hour == 1 || hour == 13) {
      hourStr = 'uma hora';
    } else {
      int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      hourStr = '$displayHour horas';
    }

    String minuteStr = '';
    if (minute > 0) {
      if (minute == 30) {
        minuteStr = ' e meia';
      } else {
        minuteStr = ' e $minute';
      }
    }

    String periodStr;
    if (hour >= 0 && hour < 6) {
      periodStr = ' da madrugada';
    } else if (hour >= 6 && hour < 12) {
      periodStr = ' da manhã';
    } else if (hour >= 12 && hour < 18) {
      periodStr = ' da tarde';
    } else {
      periodStr = ' da noite';
    }

    return '$hourStr$minuteStr$periodStr';
  }

  static String getSpokenTimeFromStr(String timeStr) {
    final hour = _parseHour(timeStr);
    if (hour == null) return timeStr;
    int minute = 0;
    try {
      final parts = timeStr.split(':');
      if (parts.length > 1) {
        minute = int.parse(parts[1].trim());
      }
    } catch (_) {}
    return getSpokenTime(hour, minute);
  }
}
