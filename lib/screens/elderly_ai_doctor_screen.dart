import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';

class ElderlyAiDoctorScreen extends StatefulWidget {
  const ElderlyAiDoctorScreen({super.key});

  @override
  State<ElderlyAiDoctorScreen> createState() => _ElderlyAiDoctorScreenState();
}

class _ElderlyAiDoctorScreenState extends State<ElderlyAiDoctorScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isThinking = false;
  String _pergunta = '';
  String? _resposta;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Olá! Eu sou o Doutor Amigo da sua rotina. Toque no círculo azul e me faça qualquer pergunta de saúde ou dos seus remédios.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    TTSService.instance.parar(caller: this);
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isThinking) return;
    await TTSService.instance.parar(caller: this);

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
        if (_pergunta.trim().isNotEmpty) {
          _consultarIA(_pergunta.trim());
        } else {
          TTSService.instance.falar(
            'Não ouvi nenhuma palavra. Toque no botão azul e tente falar de novo.',
            caller: this,
          );
        }
      }
    } else {
      setState(() {
        _pergunta = '';
        _resposta = null;
      });
      final available = await _speech.initialize(
        onError: (e) {
          debugPrint('STT Error na tela Doutor IA: $e');
          if (mounted) {
            setState(() => _isListening = false);
            TTSService.instance.falar(
              'Tive dificuldade com o microfone. Toque de novo para tentar.',
              caller: this,
            );
          }
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening) {
            if (mounted) {
              setState(() => _isListening = false);
              if (_pergunta.trim().isNotEmpty && !_isThinking) {
                _consultarIA(_pergunta.trim());
              } else if (_pergunta.trim().isEmpty && !_isThinking) {
                TTSService.instance.falar(
                  'Não ouvi sua dúvida. Toque no círculo azul e fale novamente.',
                  caller: this,
                );
              }
            }
          }
        },
      );

      if (available && mounted) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _pergunta = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: 'pt_BR',
            listenFor: const Duration(seconds: 40),
            pauseFor: const Duration(seconds: 5),
            cancelOnError: false,
          ),
        );
      } else if (mounted) {
        TTSService.instance.falar('Microfone indisponível no momento.', caller: this);
      }
    }
  }

  Future<void> _consultarIA(String perguntaTexto) async {
    if (_isThinking || perguntaTexto.trim().isEmpty) return;
    await TTSService.instance.parar(caller: this);
    setState(() => _isThinking = true);
    await TTSService.instance.falar(
      'Consultando o Doutor Amigo na nuvem. Só um instante...',
      caller: this,
    );

    final resposta = await LembreteService.instance.alexChat(perguntaTexto);
    if (mounted) {
      await TTSService.instance.parar(caller: this);
      setState(() {
        _isThinking = false;
        _resposta = resposta;
      });
      TTSService.instance.falar(resposta, caller: this);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isHighContrast = Theme.of(context).colorScheme.primary == Colors.black;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AlexFloatingHelpButton(
        textoExplicacao:
            'Esta é a tela do Doutor IA. Toque no grande botão no meio e pergunte sobre seus remédios, horários ou mal-estar. O assistente inteligente responderá por voz para te orientar.',
        onTapped: () => TTSService.instance.parar(caller: this),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(isHighContrast),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isHighContrast ? Colors.white : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isHighContrast ? Colors.black : const Color(0xFF1E88E5),
                          width: 3,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.medical_services_rounded,
                            size: 40,
                            color: isHighContrast ? Colors.black : const Color(0xFF1E88E5),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Toque no botão abaixo e pergunte qualquer dúvida de saúde, remédio ou rotina!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isHighContrast ? Colors.black : const Color(0xFF0D47A1),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botão Central de Gravação / Doutor IA
                    GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = _isListening ? 1.0 + (_pulseController.value * 0.1) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isHighContrast
                                ? (_isListening ? Colors.yellow : Colors.white)
                                : (_isListening
                                    ? const Color(0xFFD32F2F)
                                    : (_isThinking ? const Color(0xFFF57C00) : const Color(0xFF1E88E5))),
                            border: Border.all(
                              color: isHighContrast ? Colors.black : Colors.white,
                              width: 8,
                            ),
                            boxShadow: isHighContrast
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isThinking)
                                const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                                )
                              else
                                Icon(
                                  _isListening ? Icons.mic : Icons.auto_awesome,
                                  size: 64,
                                  color: isHighContrast ? Colors.black : Colors.white,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                _isThinking
                                    ? 'PENSANDO...'
                                    : (_isListening ? 'OUVINDO...' : 'PERGUNTAR'),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isHighContrast ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_pergunta.isNotEmpty && (_isListening || _isThinking)) ...[
                      Text(
                        'Você disse: "$_pergunta"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_resposta != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isHighContrast ? Colors.white : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isHighContrast ? Colors.black : const Color(0xFF2E7D32),
                            width: 4,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: isHighContrast ? Colors.black : const Color(0xFF2E7D32),
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'RESPOSTA DO DOUTOR (IA)',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: isHighContrast ? Colors.black : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            if (_pergunta.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Sua pergunta: "$_pergunta"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              _resposta!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isHighContrast ? Colors.black : const Color(0xFF1B5E20),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 70,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  TTSService.instance.parar(caller: this);
                                  TTSService.instance.falar(_resposta!, caller: this);
                                },
                                icon: const Icon(Icons.volume_up, size: 30),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('OUVIR DE NOVO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 70,
                              child: ElevatedButton.icon(
                                onPressed: _toggleListening,
                                icon: const Icon(Icons.mic, size: 30),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('OUTRA PERGUNTA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ElderlyBottomNav(
        selected: ElderlyNavDestination.aiDoctor,
      ),
    );
  }

  Widget _buildTopBar(bool isHighContrast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          Icon(Icons.medical_services_rounded, size: 32, color: isHighContrast ? Colors.black : const Color(0xFF1E88E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Doutor Amigo (IA)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isHighContrast ? Colors.black : const Color(0xFF1E88E5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
