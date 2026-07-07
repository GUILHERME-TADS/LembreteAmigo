import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../models/lembrete.dart';
import '../services/alex_ai_service.dart';
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
    await TTSService.instance.falarComEmocao(
      'Oi, eu sou o Alex. Fale com calma. Voce pode dizer: quais sao minhas tarefas, ja fiz, tomei o remedio, ou preciso de ajuda.',
      'informativo',
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
        await TTSService.instance.falarComEmocao(
          'Nao consegui ligar o reconhecimento de voz. Use os botoes da tela ou chame seu cuidador.',
          'informativo',
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
      await TTSService.instance.falarComEmocao(
        'Tive dificuldade para ouvir. Toque em ouvir de novo e fale devagar.',
        'informativo',
        caller: this,
      );
    }
  }

  Future<void> _processCommand(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;

    if (text.trim().isEmpty) {
      await _speakAndRetry(
        'Nao entendi. Pode falar de novo mais devagar?',
      );
      return;
    }

    final response = await AlexAIService.instance.processMessage(text);

    if (response.isEmergency) {
      await _triggerEmergency(text);
      _isProcessing = false;
      return;
    }

    setState(() {
      _status = response.reply;
    });
    if (response.reply.isNotEmpty) {
      await TTSService.instance.falarComEmocao(
        response.reply,
        response.effectiveEmotion,
        caller: this,
      );
    }

    if (response.isCompleteReminder) {
      await _handleAICompleteReminder(response);
    } else if (response.isCreateReminder) {
      await _handleAICreateReminder(response);
    } else if (response.isSentimentLog) {
      await _handleAISentimentLog(response);
    }

    if (response.actionType == 'general' && response.confidence < 0.4) {
      if (mounted) {
        _isProcessing = false;
        await _startListening();
      }
      return;
    }

    if (mounted) Navigator.pop(context);
    _isProcessing = false;
  }

  Future<void> _handleAICompleteReminder(AlexAIResponse response) async {
    final reminderTitle = response.actionData?['reminderTitle'] as String?;
    if (reminderTitle == null || reminderTitle.isEmpty) {
      final pending = _lembretesList.where((l) => !l.concluido).toList();
      if (pending.length == 1) {
        await LembreteService.instance.concluir(pending.first.id);
      }
      return;
    }

    final normalized = AlexAIService.instance.normalize(reminderTitle);
    final pending = _lembretesList.where((l) => !l.concluido).toList();
    for (final l in pending) {
      if (AlexAIService.instance.normalize(l.titulo).contains(normalized) ||
          normalized.contains(AlexAIService.instance.normalize(l.titulo))) {
        await LembreteService.instance.concluir(l.id);
        return;
      }
    }
  }

  Future<void> _handleAICreateReminder(AlexAIResponse response) async {
    final data = response.actionData;
    if (data == null) return;

    final titulo = data['titulo'] as String?;
    final horarioHour = data['horarioHour'] as int?;
    final horarioMinute = data['horarioMinute'] as int?;
    final categoria = data['categoria'] as String? ?? 'personalizado';
    final recorrencia = data['recorrencia'] as String? ?? 'diario';

    if (titulo == null || horarioHour == null || horarioMinute == null) return;

    final lembrete = Lembrete(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo,
      horarioHour: horarioHour,
      horarioMinute: horarioMinute,
      categoria: categoria,
      recorrencia: recorrencia,
    );
    await LembreteService.instance.adicionar(lembrete);
  }

  Future<void> _handleAISentimentLog(AlexAIResponse response) async {
    final sentiment = response.actionData?['sentiment'] as String? ?? 'neutro';
    await LembreteService.instance.registrarWelfareCheckin(sentiment);
  }

  Future<void> _speakAndRetry(String message) async {
    setState(() {
      _status = message;
    });
    await TTSService.instance.falarComEmocao(message, 'informativo', caller: this);
    if (mounted) {
      _isProcessing = false;
      await _startListening();
    }
  }

  Future<void> _triggerEmergency(String speech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId =
          prefs.getString('paired_idoso_id') ??
          SessionRoleService.unpairedIdosoId;

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

      await TTSService.instance.falarComEmocao(
        'Estou pedindo socorro e avisando quem cuida de voce agora mesmo.',
        'emergencia',
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
