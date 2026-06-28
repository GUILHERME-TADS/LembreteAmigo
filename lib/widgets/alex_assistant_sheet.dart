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
  final List<Lembrete> lembretes;
  const AlexAssistantSheet({super.key, required this.lembretes});

  @override
  State<AlexAssistantSheet> createState() => _AlexAssistantSheetState();
}

class _AlexAssistantSheetState extends State<AlexAssistantSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcription = '';
  String _status = 'Iniciando assistente...';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _speech.stop();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      final available = await _speech.initialize();
      if (!available) {
        setState(() {
          _status = 'Reconhecimento de fala indisponível.';
        });
        return;
      }

      setState(() {
        _isListening = true;
        _transcription = '';
        _status = 'Ouvindo...';
      });

      TTSService.instance.parar();

      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords;
          });
          if (result.finalResult) {
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
        _status = 'Erro de inicialização.';
      });
    }
  }

  Future<void> _processCommand(String text) async {
    final lower = text.toLowerCase();

    // 1. Emergency Command
    if (lower.contains('dor') ||
        lower.contains('ajuda') ||
        lower.contains('socorro') ||
        lower.contains('emergência') ||
        lower.contains('machuquei') ||
        lower.contains('cai') ||
        lower.contains('cair')) {
      _triggerEmergency(text);
      return;
    }

    // 2. Complete Lembrete Command
    if (lower.contains('tomei') ||
        lower.contains('conclui') ||
        lower.contains('concluí') ||
        lower.contains('fiz') ||
        lower.contains('tá pago') ||
        lower.contains('marcar') ||
        lower.contains('finalizar')) {
      await _handleCompleteReminder(lower);
      return;
    }

    // 3. List Lembretes Command
    if (lower.contains('quais') ||
        lower.contains('lista') ||
        lower.contains('ver') ||
        lower.contains('lembrete') ||
        lower.contains('remédio') ||
        lower.contains('remedio') ||
        lower.contains('hoje')) {
      _handleListReminders();
      return;
    }

    // 4. Fallback instruction
    setState(() {
      _status = 'Não entendi. Tente de novo.';
    });
    await TTSService.instance.falar(
      'Não entendi seu comando. Você pode pedir para ver os remédios de hoje, confirmar que tomou um remédio ou pedir socorro.',
      caller: this,
    );
    if (mounted) {
      _startListening();
    }
  }

  void _handleListReminders() async {
    final pendentes = widget.lembretes.where((l) => !l.concluido).toList();
    
    if (pendentes.isEmpty) {
      await TTSService.instance.falar(
        'Você não tem nenhum lembrete pendente para hoje. Bom trabalho!',
        caller: this,
      );
    } else {
      String desc = 'Você tem ${pendentes.length} lembretes pendentes: ';
      for (int i = 0; i < pendentes.length; i++) {
        final l = pendentes[i];
        final spokenTime = PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute);
        desc += '${l.titulo} às $spokenTime. ';
      }
      await TTSService.instance.falar(desc, caller: this);
    }
    
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleCompleteReminder(String text) async {
    Lembrete? match;
    for (final l in widget.lembretes) {
      if (!l.concluido) {
        final titleClean = l.titulo.toLowerCase();
        if (text.contains(titleClean) || titleClean.contains(text.replaceAll(RegExp(r'tomei|conclui|fiz|tá pago|marcar|finalizar'), '').trim())) {
          match = l;
          break;
        }
      }
    }

    if (match != null) {
      await LembreteService.instance.concluir(match.id);
      await TTSService.instance.falar(
        'Tudo certo! Marquei o lembrete ${match.titulo} como concluído.',
        caller: this,
      );
    } else {
      // Find first uncompleted medicine if none matched specific name
      final meds = widget.lembretes.where((l) => l.categoria == 'medicacao' && !l.concluido).toList();
      if (meds.isNotEmpty) {
        final first = meds.first;
        await LembreteService.instance.concluir(first.id);
        await TTSService.instance.falar(
          'Marquei o lembrete ${first.titulo} como concluído.',
          caller: this,
        );
      } else {
        await TTSService.instance.falar(
          'Não encontrei nenhum lembrete pendente correspondente para concluir.',
          caller: this,
        );
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _triggerEmergency(String speech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';
      
      // Get Idoso Name
      String idosoName = 'Idoso';
      final doc = await FirebaseFirestore.instance.collection('idosos').doc(idosoId).get();
      if (doc.exists) {
        idosoName = doc.data()?['nome'] ?? 'Idoso';
      }

      // Add emergency document to Firestore
      await FirebaseFirestore.instance.collection('alertas').add({
        'idosoId': idosoId,
        'nomeIdoso': idosoName,
        'mensagem': 'O idoso reportou emergência por comando de voz: "$speech"',
        'criadoEm': FieldValue.serverTimestamp(),
        'resolvido': false,
      });

      await TTSService.instance.falar(
        'Estou ativando o alerta de emergência e avisando seu supervisor imediatamente.',
        caller: this,
      );
    } catch (e) {
      debugPrint('Erro ao acionar alerta de emergência: $e');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10),
        ),
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
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    _buildPulsingWaves(),
                  AlexAvatar(
                    size: 140,
                    isListening: _isListening,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _status.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: _isListening ? AppColors.secondaryContainer : Colors.white54,
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
                _transcription.isEmpty ? '"Fale o que precisa..."' : '"$_transcription"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontStyle: _transcription.isEmpty ? FontStyle.italic : FontStyle.normal,
                  color: _transcription.isEmpty ? Colors.white30 : Colors.white,
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
                            _status = 'Processando...';
                          });
                          _processCommand(_transcription);
                        } else {
                          _startListening();
                        }
                      },
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                        _isListening ? 'PRONTO' : 'OUVIR DE NOVO',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            color: AppColors.secondaryContainer.withValues(alpha: (1.0 - (value - 140.0) / 60.0).clamp(0.0, 0.3)),
          ),
        );
      },
    );
  }
}
