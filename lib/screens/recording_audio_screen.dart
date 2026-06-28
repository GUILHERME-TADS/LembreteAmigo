import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/period_helper.dart';
import '../widgets/index.dart';

class RecordingAudioScreen extends StatefulWidget {
  const RecordingAudioScreen({super.key});

  @override
  State<RecordingAudioScreen> createState() => _RecordingAudioScreenState();
}

class _RecordingAudioScreenState extends State<RecordingAudioScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _hasRecorded = false;
  String _transcricao = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Aperte no meu rosto e fale o lembrete e a hora.',
        caller: this,
      );
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _hasRecorded = true;
        });
        _falarConfirmacao();
      }
    } else {
      final available = await _speech.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reconhecimento de fala não disponível neste dispositivo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      setState(() {
        _isListening = true;
        _transcricao = '';
        _hasRecorded = false;
      });
      _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          setState(() {
            _transcricao = words;
            _detectarCategoriaAutomaticamente(words);
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          localeId: 'pt_BR',
        ),
      );
    }
  }

  void _detectarCategoriaAutomaticamente(String texto) {
    final lower = texto.toLowerCase();
    
    final medicacaoKeywords = [
      'remédio', 'remedio', 'comprimido', 'cápsula', 'capsula', 'gotas', 'pomada',
      'medicamento', 'dipirona', 'losartana', 'vitamina', 'aspirina', 'paracetamol',
      'analgésico', 'ibuprofeno', 'antibiótico', 'colírio', 'colirio', 'insulina',
      'vacina', 'injeção', 'injecao', 'xarope', 'inalador', 'bombinha', 'calmante',
      'anti-inflamatório', 'antiinflamatorio', 'sinvastatina', 'metformina',
      'enalapril', 'omeprazol', 'rivotril', 'pastilha', 'pílula', 'pilula', 'suplemento'
    ];
    
    final refeicoesKeywords = [
      'almoço', 'almoco', 'jantar', 'café', 'cafe', 'refeição', 'refeicao',
      'comer', 'comida', 'lanche', 'café da manhã', 'cafedamanha', 'janta',
      'alimentar', 'fruta', 'sopa', 'chá', 'cha', 'suco', 'leite', 'biscoito',
      'pão', 'pao', 'merenda', 'ceia', 'desjejum', 'sobremesa', 'refeicoes'
    ];
    
    final exercicioKeywords = [
      'caminhar', 'caminhada', 'exercício', 'exercicio', 'alongamento', 'fisioterapia',
      'andar', 'academia', 'alongar', 'treino', 'treinar', 'passeio', 'passear',
      'correr', 'corrida', 'fisio', 'ginástica', 'ginastica', 'mexer', 'exercitar',
      'hidroginástica', 'hidroginastica', 'pilates', 'yoga', 'ioga', 'alongar-se'
    ];
    
    final hidratacaoKeywords = [
      'água', 'agua', 'beber', 'copo', 'hidratar', 'hidratacao', 'hidratação',
      'líquido', 'liquido', 'garrafa', 'copinho', 'gole', 'beber água', 'beber agua',
      'sede', 'hidratando', 'copo d\'água', 'copo d\'agua'
    ];

    for (final kw in medicacaoKeywords) {
      if (lower.contains(kw)) {
        setState(() => _selectedCategory = 'medicacao');
        return;
      }
    }
    for (final kw in hidratacaoKeywords) {
      if (lower.contains(kw)) {
        setState(() => _selectedCategory = 'hidratacao');
        return;
      }
    }
    for (final kw in refeicoesKeywords) {
      if (lower.contains(kw)) {
        setState(() => _selectedCategory = 'refeicoes');
        return;
      }
    }
    for (final kw in exercicioKeywords) {
      if (lower.contains(kw)) {
        setState(() => _selectedCategory = 'exercicio');
        return;
      }
    }
  }

  static const Map<String, int> _numerosPorExtenso = {
    'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3,
    'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8,
    'nove': 9, 'dez': 10, 'onze': 11, 'doze': 12, 'treze': 13,
    'quatorze': 14, 'catorze': 14, 'quinze': 15, 'dezesseis': 16,
    'dezasseis': 16, 'dezessete': 17, 'dezoito': 18,
    'dezenove': 19, 'vinte': 20, 'trinta': 30, 'quarenta': 40,
    'cinquenta': 50,
  };

  static String _normalizarPalavrasParaNumeros(String texto) {
    String res = texto.toLowerCase();

    // Converter "e meia" para "e 30"
    res = res.replaceAll(RegExp(r'\be\s+meia\b', caseSensitive: false), 'e 30');

    // 1. Substituir dezenas compostas (ex: "vinte e dois" -> "22")
    final dezenas = {
      'vinte': 20, 'trinta': 30, 'quarenta': 40, 'cinquenta': 50
    };
    final unidades = {
      'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3,
      'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9
    };

    for (final dezena in dezenas.keys) {
      for (final unidade in unidades.keys) {
        final regex = RegExp('\\b$dezena\\s+e\\s+$unidade\\b', caseSensitive: false);
        final valor = dezenas[dezena]! + unidades[unidade]!;
        res = res.replaceAll(regex, valor.toString());
      }
    }

    // 2. Substituir números simples (ex: "oito" -> "8", "vinte" -> "20")
    // Ordenar as chaves por comprimento decrescente para não substituir substrings incorretamente
    final chavesOrdenadas = _numerosPorExtenso.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    for (final chave in chavesOrdenadas) {
      final regex = RegExp('\\b$chave\\b', caseSensitive: false);
      res = res.replaceAll(regex, _numerosPorExtenso[chave]!.toString());
    }

    return res;
  }

  (int, int, String)? _extrairHorario(String texto) {
    final textoNormalizado = _normalizarPalavrasParaNumeros(texto);
    final textoLower = textoNormalizado.toLowerCase().trim();

    int hour = -1;
    int minute = 0;
    String? matchedString;

    // 1. Verificar meio-dia e meia-noite
    final regexMeioDia = RegExp(r'(?:^|\s+)meio[\s-]dia\b', caseSensitive: false);
    final regexMeiaNoite = RegExp(r'(?:^|\s+)meia[\s-]noite\b', caseSensitive: false);

    if (regexMeioDia.hasMatch(textoLower)) {
      hour = 12;
      minute = 0;
      matchedString = regexMeioDia.firstMatch(textoLower)!.group(0);
    } else if (regexMeiaNoite.hasMatch(textoLower)) {
      hour = 0;
      minute = 0;
      matchedString = regexMeiaNoite.firstMatch(textoLower)!.group(0);
    } else {
      // 2. Tentar padrões de horário (usando (?:^|\s+) em vez de \b para suportar caracteres com acento como à)
      final padroes = [
        // hh e mm (ex: "8 e 20", "18 e 45")
        RegExp(r'(?:^|\s+)(?:[àa]s?\s+)?([0-2]?\d)\s*(?:horas?)?\s+e\s+([0-5]\d)\b'),
        // hh:mm ou hhhmm (ex: "08:20", "18h45")
        RegExp(r'(?:^|\s+)(?:[àa]s?\s+)?([0-2]?\d)[:h](\d{2})\b'),
        // hh horas (ex: "8 horas", "18h")
        RegExp(r'(?:^|\s+)(?:[àa]s?\s+)?([0-2]?\d)\s*(?:horas?|h)\b'),
        // às hh (ex: "às 8", "as 10")
        RegExp(r'(?:^|\s+)(?:[àa]s)\s+([0-2]?\d)\b'),
        // hh da noite/manhã (ex: "8 da noite", "10 de manha")
        RegExp(r'(?:^|\s+)([0-2]?\d)\s*(?:da|de|pela|do)\s+(?:madrugada|manh[ãa]|tarde|noite)\b'),
      ];

      for (final regex in padroes) {
        final match = regex.firstMatch(textoLower);
        if (match != null) {
          hour = int.parse(match.group(1)!);
          if (match.groupCount >= 2 && match.group(2) != null) {
            minute = int.parse(match.group(2)!);
          }
          matchedString = match.group(0);
          break;
        }
      }
    }

    if (hour == -1) return null;

    // Ajustar AM/PM com base no turno mencionado no texto original
    final temTarde = RegExp(r'\btarde\b').hasMatch(textoLower);
    final temNoite = RegExp(r'\bnoite\b').hasMatch(textoLower);
    final temManha = RegExp(r'\bmanh[ãa]\b').hasMatch(textoLower);
    final temMadrugada = RegExp(r'\bmadrugada\b').hasMatch(textoLower);

    if (temMadrugada) {
      if (hour >= 13) hour -= 12;
    } else if (temManha && !temTarde && !temNoite) {
      if (hour >= 13) hour -= 12;
    } else if (temTarde) {
      if (hour >= 1 && hour <= 11) hour += 12;
    } else if (temNoite) {
      if (hour == 12) {
        hour = 0;
      } else if (hour >= 1 && hour <= 11) {
        hour += 12;
      }
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    // Limpeza do texto para gerar o título limpo
    String limpo = textoNormalizado;

    // Remover o padrão do horário encontrado (case insensitive)
    if (matchedString != null) {
      limpo = limpo.replaceFirst(RegExp(RegExp.escape(matchedString), caseSensitive: false), '');
    }

    // Remover a preposição "às" ou "as" especificamente (lidando com acentos sem quebrar limites de palavras)
    limpo = limpo.replaceAll(RegExp(r'(?:^|\s+)[àa]s(?:\s+|$)', caseSensitive: false), ' ');

    // Remover quaisquer preposições de tempo e palavras de turnos restantes
    limpo = limpo
        .replaceAll(RegExp(r'\b(?:ao|de|da|do|pela|pelo|no|na|turno\s+da|turno\s+de|per[ií]odo\s+da|per[ií]odo\s+de)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:madrugada|manh[ãa]|tarde|noite|horas?|h)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bmanhã(?:\b|\s+|$)', caseSensitive: false), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return (hour, minute, limpo);
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'icon': Icons.medication, 'label': 'Remédio', 'key': 'medicacao', 'color': AppColors.medicationsColor},
      {'icon': Icons.restaurant, 'label': 'Refeição', 'key': 'refeicoes', 'color': AppColors.mealsColor},
      {'icon': Icons.directions_walk, 'label': 'Exercício', 'key': 'exercicio', 'color': AppColors.tertiaryContainer},
      {'icon': Icons.water_drop, 'label': 'Água', 'key': 'hidratacao', 'color': AppColors.voiceFeedbackBlue},
      {'icon': Icons.notifications, 'label': 'Personalizado', 'key': 'personalizado', 'color': AppColors.customColor},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: categories.map((cat) {
              final key = cat['key'] as String;
              final color = cat['color'] as Color;
              final selected = _selectedCategory == key;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = selected ? null : key),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.2) : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected ? color : color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat['icon'] as IconData, size: 24, color: selected ? Colors.white : color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? color : AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge((int, int, String) horario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 18, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            '${horario.$1.toString().padLeft(2, '0')}:${horario.$2.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(width: 8),
          const Text('detectado', style: TextStyle(fontSize: 14, color: AppColors.onPrimaryContainer)),
        ],
      ),
    );
  }

  void _falarConfirmacao() {
    final extraido = _extrairHorario(_transcricao);
    if (extraido != null) {
      final hour = extraido.$1;
      final minute = extraido.$2;
      final titulo = extraido.$3.isNotEmpty ? extraido.$3 : _transcricao;
      final spokenTime = PeriodHelper.getSpokenTime(hour, minute);
      final texto = 'Entendi: $titulo às $spokenTime. Está correto?';
      TTSService.instance.falar(texto, caller: this);
    } else {
      TTSService.instance.falar(
        'Não entendi o horário do lembrete. Por favor, tente de novo dizendo o lembrete e a hora.',
        caller: this,
      );
    }
  }

  void _reiniciarGravacao() async {
    await TTSService.instance.parar(caller: this);
    setState(() {
      _transcricao = '';
      _hasRecorded = false;
      _selectedCategory = null;
    });
    await TTSService.instance.falar('Tudo bem, pode falar novamente.', caller: this);
    _toggleListening();
  }

  void _salvarLembrete((int, int, String) extraido) async {
    final now = DateTime.now();
    final titulo = extraido.$3.isNotEmpty ? extraido.$3 : _transcricao;

    final lembrete = Lembrete(
      id: now.millisecondsSinceEpoch.toString(),
      titulo: titulo,
      horarioHour: extraido.$1,
      horarioMinute: extraido.$2,
      categoria: _selectedCategory ?? 'personalizado',
    );
    await LembreteService.instance.adicionar(lembrete);
    if (!mounted) return;
    Navigator.pop(context, lembrete);
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _speech.stop();
    super.dispose();
  }

  Widget _buildBottomPanel(dynamic horario) {
    if (!_hasRecorded || _transcricao.isEmpty) {
      return const SizedBox(height: 12);
    }

    if (horario != null) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _reiniciarGravacao,
                icon: const Icon(Icons.refresh, size: 28),
                label: const Text(
                  'Não, falar de novo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                onPressed: () => _salvarLembrete(horario),
                icon: const Icon(Icons.check_circle_outline, size: 28),
                label: const Text(
                  'Sim, está correto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tertiaryFixedDim,
                  foregroundColor: AppColors.onTertiaryFixed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 80,
        child: ElevatedButton.icon(
          onPressed: _reiniciarGravacao,
          icon: const Icon(Icons.refresh, size: 28),
          label: const Text(
            'Não entendi, tentar de novo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final horario = _hasRecorded && _transcricao.isNotEmpty
        ? _extrairHorario(_transcricao)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      TTSService.instance.parar(caller: this);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Text('Lembrete Amigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      TTSService.instance.falar(
                        'Aperte no meu rosto e fale o lembrete e a hora.',
                        caller: this,
                      );
                    },
                    child: const AlexAvatar(size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Fale seu lembrete',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Diga o lembrete e o horário.\nEx: "15:30 tomar dipirona"',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          TTSService.instance.parar(caller: this);
                          _toggleListening();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AlexAvatar(
                                  isListening: _isListening,
                                  size: 180,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isListening
                                          ? AppColors.voiceFeedbackBlue
                                          : AppColors.secondaryContainer,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 4),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.mic : Icons.touch_app,
                                      color: _isListening
                                          ? Colors.white
                                          : AppColors.onSecondaryContainer,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? AppColors.voiceFeedbackBlue.withValues(alpha: 0.1)
                                    : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: _isListening
                                      ? AppColors.voiceFeedbackBlue
                                      : AppColors.outlineVariant,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _isListening
                                    ? 'Estou ouvindo... Toque para parar'
                                    : 'Toque no rosto para começar',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _isListening
                                      ? AppColors.voiceFeedbackBlue
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_transcricao.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _transcricao,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  TTSService.instance.falar(
                                    _transcricao,
                                    caller: this,
                                  );
                                },
                                icon: const Icon(Icons.volume_up, size: 28),
                                label: const Text(
                                  'OUVIR O LEMBRETE',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryContainer,
                                  foregroundColor: AppColors.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (horario != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildTimeBadge(horario),
                        ),
                        const SizedBox(height: 12),
                        _buildCategorySelector(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildBottomPanel(horario),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
  }
}
