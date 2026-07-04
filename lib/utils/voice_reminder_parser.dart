class VoiceReminderParseResult {
  final int hour;
  final int minute;
  final String title;

  const VoiceReminderParseResult({
    required this.hour,
    required this.minute,
    required this.title,
  });

  (int, int, String) toRecord() => (hour, minute, title);
}

class VoiceReminderParser {
  static const Map<String, int> _simpleNumbers = {
    'zero': 0,
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'quatorze': 14,
    'catorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezasseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
  };

  static const Map<String, int> _tens = {
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
  };

  static const Map<String, int> _units = {
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
  };

  static VoiceReminderParseResult? parse(String text) {
    final normalized = _wordsToNumbers(_normalize(text));

    final special = _parseSpecialTime(normalized);
    if (special != null) {
      return _result(special.$1, special.$2, text, normalized, special.$3);
    }

    final relative = _parseRelativeTime(normalized);
    if (relative != null) {
      return _result(relative.$1, relative.$2, text, normalized, relative.$3);
    }

    final absolute = _parseAbsoluteTime(normalized);
    if (absolute != null) {
      return _result(absolute.$1, absolute.$2, text, normalized, absolute.$3);
    }

    return null;
  }

  static (int, int, String)? _parseSpecialTime(String text) {
    final meioDia = RegExp(
      r'(?:^|\s+)meio[\s-]dia(?:\s+e\s+([0-5]?\d))?\b',
    ).firstMatch(text);
    if (meioDia != null) {
      return (12, _parseMinute(meioDia.group(1)) ?? 0, meioDia.group(0)!);
    }

    final meiaNoite = RegExp(
      r'(?:^|\s+)meia[\s-]noite(?:\s+e\s+([0-5]?\d))?\b',
    ).firstMatch(text);
    if (meiaNoite != null) {
      return (0, _parseMinute(meiaNoite.group(1)) ?? 0, meiaNoite.group(0)!);
    }

    return null;
  }

  static (int, int, String)? _parseRelativeTime(String text) {
    final paraAs = RegExp(
      r'(?:^|\s+)(?:faltam\s+)?([0-5]?\d)\s+(?:minutos?\s+)?(?:para|pra|pras|pro|pros)\s+(?:as\s+)?([0-2]?\d)(?:\s+horas?)?(?:\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite))?\b',
    ).firstMatch(text);
    if (paraAs != null) {
      final minutesBefore = _parseMinute(paraAs.group(1));
      final targetHour = int.tryParse(paraAs.group(2)!);
      if (minutesBefore == null ||
          targetHour == null ||
          minutesBefore <= 0 ||
          minutesBefore >= 60) {
        return null;
      }

      final adjustedTarget = _applyPeriod(targetHour, paraAs.group(3), text);
      if (adjustedTarget == null) return null;

      final totalMinutes =
          (adjustedTarget * 60 - minutesBefore) % (24 * 60);
      return (
        totalMinutes ~/ 60,
        totalMinutes % 60,
        paraAs.group(0)!,
      );
    }

    final menos = RegExp(
      r'(?:^|\s+)(?:as\s+)?([0-2]?\d)(?:\s+horas?)?\s+menos\s+([0-5]?\d)(?:\s+minutos?)?(?:\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite))?\b',
    ).firstMatch(text);
    if (menos != null) {
      final targetHour = int.tryParse(menos.group(1)!);
      final minutesBefore = _parseMinute(menos.group(2));
      if (targetHour == null ||
          minutesBefore == null ||
          minutesBefore <= 0 ||
          minutesBefore >= 60) {
        return null;
      }

      final adjustedTarget = _applyPeriod(targetHour, menos.group(3), text);
      if (adjustedTarget == null) return null;

      final totalMinutes =
          (adjustedTarget * 60 - minutesBefore) % (24 * 60);
      return (
        totalMinutes ~/ 60,
        totalMinutes % 60,
        menos.group(0)!,
      );
    }

    return null;
  }

  static (int, int, String)? _parseAbsoluteTime(String text) {
    final patterns = [
      RegExp(
        r'(?:^|\s+)(?:as\s+)?([0-2]?\d)\s*(?:h|:)\s*([0-5]\d)\b(?:\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite))?',
      ),
      RegExp(
        r'(?:^|\s+)(?:as\s+)?([0-2]?\d)\s*(?:horas?)?\s+e\s+([0-5]?\d)(?:\s+minutos?)?\b(?:\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite))?',
      ),
      RegExp(
        r'(?:^|\s+)(?:as\s+)?([0-2]?\d)\s*(?:horas?|h)\b(?:\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite))?',
      ),
      RegExp(
        r'(?:^|\s+)(?:as\s+)?([0-2]?\d)\s+(?:da|de|do|pela|pelo)\s+(madrugada|manha|tarde|noite)\b',
      ),
      RegExp(r'(?:^|\s+)as\s+([0-2]?\d)\b'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(text);
      if (match == null) continue;

      final rawHour = int.tryParse(match.group(1)!);
      final rawMinute = match.groupCount >= 2 ? _parseMinute(match.group(2)) : 0;
      final explicitPeriod = match.groupCount >= 3 ? match.group(3) : null;
      if (rawHour == null || rawMinute == null) continue;

      final adjustedHour = _applyPeriod(rawHour, explicitPeriod, text);
      if (adjustedHour == null) continue;
      if (adjustedHour < 0 || adjustedHour > 23 || rawMinute > 59) continue;

      return (adjustedHour, rawMinute, match.group(0)!);
    }

    return null;
  }

  static int? _parseMinute(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 59) return null;
    return parsed;
  }

  static int? _applyPeriod(int hour, String? explicitPeriod, String text) {
    if (hour < 0 || hour > 23) return null;

    final period = explicitPeriod ??
        (RegExp(r'\bmadrugada\b').hasMatch(text)
            ? 'madrugada'
            : RegExp(r'\bmanha\b').hasMatch(text)
                ? 'manha'
                : RegExp(r'\btarde\b').hasMatch(text)
                    ? 'tarde'
                    : RegExp(r'\bnoite\b').hasMatch(text)
                        ? 'noite'
                        : null);

    switch (period) {
      case 'madrugada':
      case 'manha':
        if (hour == 12) return 0;
        if (hour >= 13) return hour - 12;
        return hour;
      case 'tarde':
        if (hour >= 1 && hour <= 11) return hour + 12;
        return hour;
      case 'noite':
        if (hour == 12) return 0;
        if (hour >= 1 && hour <= 11) return hour + 12;
        return hour;
      default:
        return hour;
    }
  }

  static VoiceReminderParseResult _result(
    int hour,
    int minute,
    String original,
    String normalized,
    String matchedTime,
  ) {
    final title = _cleanTitle(original, normalized, matchedTime);
    return VoiceReminderParseResult(hour: hour, minute: minute, title: title);
  }

  static String _cleanTitle(
    String original,
    String normalized,
    String matchedTime,
  ) {
    var cleaned = normalized.replaceFirst(
      RegExp(RegExp.escape(matchedTime), caseSensitive: false),
      ' ',
    );

    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'\b(?:as|a|ao|de|da|do|pela|pelo|no|na|turno|periodo)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\b(?:madrugada|manha|tarde|noite)\b'), ' ')
        .replaceAll(RegExp(r'\b(?:horas?|h|minutos?)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isNotEmpty) return cleaned;
    return original.trim();
  }

  static String _wordsToNumbers(String text) {
    var result = text.replaceAll(RegExp(r'\be\s+meia\b'), 'e 30');

    for (final ten in _tens.entries) {
      for (final unit in _units.entries) {
        result = result.replaceAll(
          RegExp('\\b${ten.key}\\s+e\\s+${unit.key}\\b'),
          '${ten.value + unit.value}',
        );
      }
    }

    final keys = _simpleNumbers.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      result = result.replaceAll(
        RegExp('\\b$key\\b'),
        _simpleNumbers[key]!.toString(),
      );
    }

    return result;
  }

  static String _normalize(String text) {
    var result = text.toLowerCase();
    final replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'Ã¡': 'a',
      'Ã ': 'a',
      'Ã¢': 'a',
      'Ã£': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'Ã©': 'e',
      'Ãª': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Ã­': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ã³': 'o',
      'Ã´': 'o',
      'Ãµ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ãº': 'u',
      'ç': 'c',
      'Ã§': 'c',
    };

    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result
        .replaceAll(RegExp(r'[,.!?;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
