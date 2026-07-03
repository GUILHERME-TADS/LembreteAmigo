import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../models/lembrete.dart';
import '../utils/period_helper.dart';
import 'alex_avatar.dart';

class AlexAssistantSheet extends StatefulWidget {
  final List<Lembrete>? lembretes;
  const AlexAssistantSheet({super.key, this.lembretes});

  @override
  State<AlexAssistantSheet> createState() => _AlexAssistantSheetState();
}

class _AlexAssistantSheetState extends State<AlexAssistantSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcription = '';
  String _status = 'Iniciando assistente...';

  List<Lembrete> get _lembretesList =>
      widget.lembretes ?? LembreteService.instance.lembretes;

  @override
  void initState() {
    super.initState();
    _introduceAndListen();
  }

  @override
  void dispose() {
    _speech.stop();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _introduceAndListen() async {
    setState(() {
      _status = 'Oi, eu sou o Alex.';
    });
    await TTSService.instance.falar(
      'Oi, eu sou o Alex. Fale com calma. Voce pode dizer: quais sao minhas tarefas, ja fiz, tomei o remedio, ou preciso de ajuda.',
      caller: this,
    );
    if (mounted) {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_isProcessing) return;
    try {
      final available = await _speech.initialize();
      if (!available) {
        setState(() {
          _isListening = false;
          _status = 'Nao consegui ouvir voce.';
        });
        await TTSService.instance.falar(
          'Nao consegui ligar o reconhecimento de voz. Use os botoes da tela ou chame seu cuidador.',
          caller: this,
        );
        return;
      }

      setState(() {
        _isListening = true;
        _transcription = '';
        _status = 'Estou ouvindo. Pode falar.';
      });

      await TTSService.instance.parar();

      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() {
              _isListening = false;
              _status = 'Entendi. Vou verificar.';
            });
            _processCommand(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 15),
          localeId: 'pt_BR',
        ),
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _status = 'Tive dificuldade para ouvir.';
      });
      await TTSService.instance.falar(
        'Tive dificuldade para ouvir. Toque em ouvir de novo e fale devagar.',
        caller: this,
      );
    }
  }

  Future<void> _processCommand(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;
    final lower = _normalizeSpeech(text);

    if (lower.isEmpty) {
      await _askToRepeat();
      _isProcessing = false;
      return;
    }

    if (_hasAny(lower, const [
      'dor',
      'ajuda',
      'socorro',
      'emergencia',
      'passando mal',
      'machuquei',
      'cai',
      'cair',
      'queda',
      'chama alguem',
      'chamar alguem',
      'preciso de alguem',
    ])) {
      await _triggerEmergency(text);
      _isProcessing = false;
      return;
    }

    if (_hasAny(lower, const [
      'tomei',
      'ja tomei',
      'conclui',
      'fiz',
      'ja fiz',
      'bebi',
      'comi',
      'terminei',
      'marcar',
      'finalizar',
      'pronto',
      'feito',
      'ok',
    ])) {
      await _handleCompleteReminder(lower);
      _isProcessing = false;
      return;
    }

    if (_hasAny(lower, const [
      'quais',
      'lista',
      'ver',
      'lembrete',
      'remedio',
      'tarefas',
      'atividade',
      'hoje',
      'o que tenho',
      'minha rotina',
    ])) {
      await _handleListReminders();
      _isProcessing = false;
      return;
    }

    await _askToRepeat();
    _isProcessing = false;
  }

  String _normalizeSpeech(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _hasAny(String text, List<String> words) {
    return words.any(text.contains);
  }

  Future<void> _askToRepeat() async {
    setState(() {
      _status = 'Nao entendi ainda.';
    });
    await TTSService.instance.falar(
      'Desculpe, eu nao entendi. Fale uma frase curta, como: minhas tarefas, ja fiz, tomei o remedio, ou preciso de ajuda.',
      caller: this,
    );
    if (mounted) {
      _isProcessing = false;
      await _startListening();
    }
  }

  Future<void> _handleListReminders() async {
    final pendentes = _lembretesList.where((l) => !l.concluido).toList();

    if (pendentes.isEmpty) {
      await TTSService.instance.falar(
        'Muito bem. Voce ja terminou todas as suas tarefas de hoje.',
        caller: this,
      );
    } else {
      String desc = 'Voce tem ${pendentes.length} tarefas para fazer hoje. ';
      for (int i = 0; i < pendentes.length; i++) {
        final l = pendentes[i];
        final spokenTime = PeriodHelper.getSpokenTime(
          l.horarioHour,
          l.horarioMinute,
        );
        desc += '${i + 1}. ${l.titulo}, as $spokenTime. ';
      }
      await TTSService.instance.falar(desc, caller: this);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleCompleteReminder(String text) async {
    final pending = _lembretesList.where((l) => !l.concluido).toList();
    Lembrete? match;
    final commandWords = RegExp(
      r'\b(tomei|ja|conclui|fiz|bebi|comi|terminei|marcar|finalizar|pronto|feito|ok|o|a|um|uma|remedio|atividade|tarefa)\b',
    );
    final meaningfulText = text
        .replaceAll(commandWords, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final l in pending) {
      final titleClean = _normalizeSpeech(l.titulo);
      if (titleClean.isEmpty) continue;
      if (text.contains(titleClean) ||
          (meaningfulText.length >= 3 && titleClean.contains(meaningfulText))) {
        match = l;
        break;
      }
    }

    if (match != null) {
      await LembreteService.instance.concluir(match.id);
      await TTSService.instance.falar(
        'Tudo certo. Marquei que voce terminou: ${match.titulo}.',
        caller: this,
      );
    } else {
      final meds = pending.where((l) => l.categoria == 'medicacao').toList();
      final canCompleteOnlyTask =
          pending.length == 1 &&
          _hasAny(text, const ['fiz', 'ja fiz', 'pronto', 'feito', 'ok']);
      final canCompleteOnlyMedicine =
          meds.length == 1 &&
          _hasAny(text, const ['tomei', 'ja tomei', 'remedio']);

      if (canCompleteOnlyTask || canCompleteOnlyMedicine) {
        final item = canCompleteOnlyMedicine ? meds.first : pending.first;
        await LembreteService.instance.concluir(item.id);
        await TTSService.instance.falar(
          'Tudo certo. Marquei que voce terminou: ${item.titulo}.',
          caller: this,
        );
      } else {
        setState(() {
          _status = 'Preciso saber qual tarefa.';
        });
        await TTSService.instance.falar(
          'Eu preciso saber qual tarefa voce fez. Fale, por exemplo: tomei o remedio da manha, ou fiz a caminhada.',
          caller: this,
        );
        if (mounted) {
          _isProcessing = false;
          await _startListening();
          return;
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _triggerEmergency(String speech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';

      String idosoName = 'Idoso';
      final doc = await FirebaseFirestore.instance
          .collection('idosos')
          .doc(idosoId)
          .get();
      if (doc.exists) {
        idosoName = doc.data()?['nome'] ?? 'Idoso';
      }

      await FirebaseFirestore.instance.collection('alertas').add({
        'idosoId': idosoId,
        'nomeIdoso': idosoName,
        'mensagem': 'O idoso reportou emergencia por comando de voz: "$speech"',
        'criadoEm': FieldValue.serverTimestamp(),
        'resolvido': false,
      });

      await TTSService.instance.falar(
        'Estou pedindo socorro e avisando quem cuida de voce agora mesmo.',
        caller: this,
      );
    } catch (e) {
      debugPrint('Erro ao acionar alerta de emergencia: $e');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assistente Alex',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening) _buildPulsingWaves(),
                    AlexAvatar(size: 140, isListening: _isListening),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _status.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: _isListening
                      ? AppColors.secondaryContainer
                      : Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _transcription.isEmpty
                      ? '"Fale: minhas tarefas, ja fiz, ou preciso de ajuda"'
                      : '"$_transcription"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontStyle: _transcription.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: _transcription.isEmpty
                        ? Colors.white30
                        : Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_isListening) {
                            _speech.stop();
                            setState(() {
                              _isListening = false;
                              _status = 'Vou verificar.';
                            });
                            _processCommand(_transcription);
                          } else {
                            _startListening();
                          }
                        },
                        icon: Icon(_isListening ? Icons.stop : Icons.mic),
                        label: Text(
                          _isListening ? 'PRONTO' : 'OUVIR DE NOVO',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingWaves() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 140.0, end: 200.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: value,
          height: value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondaryContainer.withValues(
              alpha: (1.0 - (value - 140.0) / 60.0).clamp(0.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}
