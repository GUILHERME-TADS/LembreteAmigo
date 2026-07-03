import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../services/notification_service.dart';
import '../services/vibration_service.dart';
import '../widgets/index.dart';

class ActiveReminderScreen extends StatefulWidget {
  const ActiveReminderScreen({super.key});

  @override
  State<ActiveReminderScreen> createState() => _ActiveReminderScreenState();
}

class _ActiveReminderScreenState extends State<ActiveReminderScreen>
    with WidgetsBindingObserver {
  Lembrete? lembrete;
  String _speakText = '';
  String? _lembreteId;
  bool _isSpeakingLoopActive = false;
  bool _isLoopPaused = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListeningForCommand = false;
  Timer? _urgencyReinforcementTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LembreteService.instance.carregar();
    LembreteService.instance.notifier.addListener(_buscarLembrete);
  }

  void _buscarLembrete() {
    if (lembrete != null || _lembreteId == null) return;
    try {
      final l = LembreteService.instance.lembretes.firstWhere(
        (item) => item.id == _lembreteId,
      );
      setState(() {
        lembrete = l;
      });
      _startReminderLoop(l);
    } catch (_) {}
  }

  Future<void> _startReminderLoop(Lembrete l) async {
    if (_isSpeakingLoopActive) return;
    _isSpeakingLoopActive = true;
    _isLoopPaused = false;

    // Start parallel vibration loop
    _startVibrationLoop();

    // Critical reinforcement check
    if (l.urgencia == 'critico') {
      _urgencyReinforcementTimer = Timer(const Duration(minutes: 2), () async {
        if (mounted && _isSpeakingLoopActive && !l.concluido) {
          _isSpeakingLoopActive = false;
          VibrationService.stopVibration();
          
          await LembreteService.instance.registrarDificuldade(
            l.id,
            'ALERTA CRÍTICO: Idoso não respondeu ao lembrete crítico de remédio em 2 minutos. Reforço automático ativado.',
          );
          
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/reinforcement-alert',
              (route) => false,
              arguments: {
                'categoria': l.categoria,
                'tipo': 'dificuldade',
                'urgencia': 'critico',
              },
            );
          }
        }
      });
    }

    while (mounted && _isSpeakingLoopActive) {
      if (_isLoopPaused) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final isCrit = l.urgencia == 'critico';
      final isImp = l.urgencia == 'importante';
      final prefix = isCrit 
          ? 'ALERTA URGENTE E ESSENCIAL! Por favor, faça agora: ' 
          : (isImp ? 'Aviso importante! Está na hora de: ' : 'Atenção! Está na hora de: ');

      if (l.categoria == 'medicacao') {
        _speakText = '$prefix tomar o seu remédio: ${l.titulo}.';
      } else if (l.categoria == 'refeicoes') {
        _speakText = '$prefix comer: ${l.titulo}. Faça a sua refeição.';
      } else if (l.categoria == 'hidratacao') {
        _speakText = '$prefix se hidratar: ${l.titulo}. Beba um copo de água agora.';
      } else if (l.categoria == 'exercicio') {
        _speakText = '$prefix fazer o seu exercício físico: ${l.titulo}. Faça a sua atividade.';
      } else {
        _speakText = '$prefix sua atividade: ${l.titulo}.';
      }

      await TTSService.instance.falar(_speakText, caller: this);

      final waitSeconds = isCrit ? 2 : (isImp ? 3 : 4);
      for (int i = 0; i < (waitSeconds * 10); i++) {
        if (!mounted || !_isSpeakingLoopActive || _isLoopPaused) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _startVibrationLoop() async {
    while (mounted && _isSpeakingLoopActive) {
      if (_isLoopPaused) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      
      final isCrit = lembrete?.urgencia == 'critico';
      final isImp = lembrete?.urgencia == 'importante';
      
      await VibrationService.startVibration();
      if (isCrit) {
        await Future.delayed(const Duration(seconds: 4));
      } else if (isImp) {
        await VibrationService.stopVibration();
        await Future.delayed(const Duration(milliseconds: 150));
        await VibrationService.startVibration();
        await Future.delayed(const Duration(milliseconds: 400));
      } else {
        for (int i = 0; i < 10; i++) {
          if (!mounted || !_isSpeakingLoopActive || _isLoopPaused) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      await VibrationService.stopVibration();
      await Future.delayed(Duration(milliseconds: isCrit ? 200 : 1000));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Lembrete) {
      if (lembrete == null) {
        setState(() {
          lembrete = args;
        });
        _startReminderLoop(args);
      }
    } else if (args is String) {
      _lembreteId = args;
      _buscarLembrete();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — restart loops if they should be active
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (_isSpeakingLoopActive && lembrete != null && isCurrentRoute) {
        setState(() {
          _isLoopPaused = false;
        });
        VibrationService.startVibration();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background — stop TTS and vibration
      setState(() {
        _isLoopPaused = true;
      });
      TTSService.instance.parar();
      VibrationService.stopVibration();
    }
  }

  Future<void> _listenForVoiceConfirmation() async {
    try {
      _isLoopPaused = true;
      VibrationService.stopVibration();
      await TTSService.instance.parar(caller: this);

      final available = await _speech.initialize();
      if (!available) {
        await TTSService.instance.falar(
          'Reconhecimento de voz indisponivel. Use os botoes da tela.',
          caller: this,
        );
        if (mounted) setState(() => _isLoopPaused = false);
        return;
      }

      if (!mounted) return;
      setState(() => _isListeningForCommand = true);
      _speech.listen(
        localeId: 'pt_BR',
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
        ),
        onResult: (result) {
          if (result.finalResult) {
            _handleVoiceCommand(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao ouvir comando de voz: $e');
      if (mounted) {
        setState(() {
          _isListeningForCommand = false;
          _isLoopPaused = false;
        });
      }
    }
  }

  Future<void> _handleVoiceCommand(String text) async {
    final lower = text.toLowerCase().trim();
    if (!mounted) return;
    setState(() => _isListeningForCommand = false);
    await _speech.stop();

    if (lower.contains('ad') ||
        lower.contains('depois') ||
        lower.contains('mais tarde') ||
        lower.contains('daqui a pouco') ||
        lower.contains('me lembra') ||
        lower.contains('avisa')) {
      _isSpeakingLoopActive = false;
      _isLoopPaused = false;
      if (lembrete != null) {
        await LembreteService.instance.adiar(lembrete!.id, 10);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/reinforcement-alert',
        (route) => false,
        arguments: {'categoria': lembrete?.categoria},
      );
      return;
    }

    if (lower.contains('nao') ||
        lower.contains('não') ||
        lower.contains('ajuda') ||
        lower.contains('consegui') ||
        lower.contains('dificuldade') ||
        lower.contains('difícil') ||
        lower.contains('dificil') ||
        lower == 'n' ||
        lower == 'no') {
      _isSpeakingLoopActive = false;
      _isLoopPaused = false;
      if (lembrete != null) {
        await LembreteService.instance.registrarDificuldade(
          lembrete!.id,
          'O idoso informou por voz que nao conseguiu realizar a atividade.',
        );
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/reinforcement-alert',
        (route) => false,
        arguments: {'categoria': lembrete?.categoria, 'tipo': 'dificuldade'},
      );
      return;
    }

    if (lower.contains('tomei') ||
        lower.contains('fiz') ||
        lower.contains('bebi') ||
        lower.contains('comi') ||
        lower.contains('conclui') ||
        lower.contains('concluí') ||
        lower.contains('confirm') ||
        lower.contains('ok') ||
        lower.contains('sim') ||
        lower == 's') {
      if (lembrete?.categoria == 'medicacao') {
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/take-photo-confirmation',
          arguments: lembrete?.id,
        );
      } else {
        _isSpeakingLoopActive = false;
        if (lembrete != null) {
          await LembreteService.instance.alternarConclusao(lembrete!.id);
        }
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/medication-confirmation',
          (route) => false,
          arguments: 'Atividade confirmada por voz.',
        );
      }
      return;
    }

    await TTSService.instance.falar(
      'Nao entendi. Voce pode dizer ja fiz, adiar ou nao consegui.',
      caller: this,
    );
    if (mounted) {
      setState(() => _isLoopPaused = false);
    }
  }

  @override
  void dispose() {
    _urgencyReinforcementTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _isSpeakingLoopActive = false;
    _isLoopPaused = false;
    VibrationService.stopVibration();
    _speech.stop();
    LembreteService.instance.notifier.removeListener(_buscarLembrete);
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String titleText;
    final String subtitleText;
    final IconData categoryIcon;
    final Color iconColor;
    final bool requiresPhoto;
    final String confirmButtonText;

    if (lembrete != null) {
      requiresPhoto = lembrete!.categoria == 'medicacao';
      categoryIcon = lembrete!.categoria == 'medicacao'
          ? Icons.medication
          : lembrete!.categoria == 'refeicoes'
          ? Icons.restaurant
          : lembrete!.categoria == 'hidratacao'
          ? Icons.water_drop
          : lembrete!.categoria == 'exercicio'
          ? Icons.directions_walk
          : Icons.notifications;

      iconColor = lembrete!.categoria == 'medicacao'
          ? AppColors.medicationsColor
          : lembrete!.categoria == 'refeicoes'
          ? AppColors.mealsColor
          : lembrete!.categoria == 'hidratacao'
          ? AppColors.voiceFeedbackBlue
          : lembrete!.categoria == 'exercicio'
          ? AppColors.tertiaryContainer
          : AppColors.primary;

      if (lembrete!.categoria == 'medicacao') {
        titleText = 'HORA DO REMÉDIO';
        subtitleText = 'Por favor, tome seu remédio agora.';
        confirmButtonText = 'ENTENDI, VOU TOMAR!';
      } else if (lembrete!.categoria == 'refeicoes') {
        titleText = 'HORA DE COMER';
        subtitleText = 'Por favor, faça sua refeição agora.';
        confirmButtonText = 'ENTENDI, VOU COMER!';
      } else if (lembrete!.categoria == 'hidratacao') {
        titleText = 'HORA DE BEBER ÁGUA';
        subtitleText = 'Por favor, beba um copo de água agora.';
        confirmButtonText = 'ENTENDI, VOU BEBER!';
      } else if (lembrete!.categoria == 'exercicio') {
        titleText = 'HORA DO EXERCÍCIO';
        subtitleText = 'Por favor, faça sua atividade física agora.';
        confirmButtonText = 'ENTENDI, VOU FAZER!';
      } else {
        titleText = 'HORA DO LEMBRETE';
        subtitleText = 'Por favor, faça esta atividade agora.';
        confirmButtonText = 'ENTENDI, VOU FAZER!';
      }
    } else {
      requiresPhoto = true;
      categoryIcon = Icons.medication;
      iconColor = AppColors.primary;
      titleText = 'HORA DO REMÉDIO';
      subtitleText = 'Por favor, tome seu remédio agora.';
      confirmButtonText = 'ENTENDI, VOU TOMAR!';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        TTSService.instance.parar();
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const VolumeWarningBanner(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildTopBar(context),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildPulsingMedication(
                              categoryIcon,
                              iconColor,
                              lembrete,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 2,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const MeExplicaButton(
                              textoExplicacao:
                                  'Olá! Esta tela avisa que está na hora de uma tarefa. Se você puder fazer agora, aperte o botão verde grande escrito ENTENDI. Se não puder fazer, aperte o botão de ADIAR ou DIFICULDADE.',
                            ),
                            Builder(builder: (context) {
                              final isCrit = lembrete?.urgencia == 'critico';
                              final isImp = lembrete?.urgencia == 'importante';

                              final border = Border.all(
                                color: isCrit
                                    ? Colors.red
                                    : isImp
                                        ? Colors.orange
                                        : iconColor.withValues(alpha: 0.3),
                                width: isCrit ? 6 : (isImp ? 4 : 3),
                              );

                              final shadow = [
                                BoxShadow(
                                  color: isCrit
                                      ? Colors.red.withValues(alpha: 0.25)
                                      : isImp
                                          ? Colors.orange.withValues(alpha: 0.18)
                                          : iconColor.withValues(alpha: 0.1),
                                  blurRadius: isCrit ? 24 : 16,
                                  offset: const Offset(0, 8),
                                ),
                              ];

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(24),
                                  border: border,
                                  boxShadow: shadow,
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'ATIVIDADE A FAZER:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      lembrete?.titulo ??
                                          'Carregando lembrete...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      subtitleText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),

                                    // If it is a medication and has shape/color details, show them
                                    if (lembrete?.categoria == 'medicacao' &&
                                        (lembrete?.medicamentoForma != null ||
                                            lembrete?.medicamentoCor !=
                                                null)) ...[
                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'APARÊNCIA DO REMÉDIO:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          color: AppColors.outline,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          PillVisualizer(
                                            forma: lembrete?.medicamentoForma,
                                            cor: lembrete?.medicamentoCor,
                                            fotoPath:
                                                lembrete?.medicamentoFotoPath,
                                            size: 80,
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Formato: ${lembrete?.medicamentoForma ?? "Padrão"}'
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Cor: ${lembrete?.medicamentoCor ?? "Padrão"}'
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 24),

                            // Play recorded audio if caregiver left a voice message
                            if (lembrete?.audioPath != null) ...[
                              AudioPlayerCard(
                                audioPath: lembrete!.audioPath!,
                                subtitle: 'Mensagem de voz do seu cuidador',
                              ),
                              const SizedBox(height: 24),
                            ],

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 72,
                              child: OutlinedButton.icon(
                                onPressed: _isListeningForCommand
                                    ? null
                                    : _listenForVoiceConfirmation,
                                icon: Icon(
                                  _isListeningForCommand
                                      ? Icons.hearing
                                      : Icons.mic,
                                  size: 30,
                                ),
                                label: Text(
                                  _isListeningForCommand
                                      ? 'OUVINDO...'
                                      : 'RESPONDER POR VOZ',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // BOTÃO CONFIRMAR (ENTENDI)
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  _isLoopPaused = true;
                                  VibrationService.stopVibration();
                                  AudioManager.stopAll();
                                  await TTSService.instance.parar();
                                  if (lembrete != null) {
                                    NotificationService.instance
                                        .cancelar(lembrete!.id)
                                        .catchError((e) {
                                          debugPrint(
                                            'Erro ao cancelar notificacao: $e',
                                          );
                                        });
                                  }
                                  if (requiresPhoto) {
                                    AudioManager.stopAll();
                                    await TTSService.instance.parar();
                                    await navigator.pushNamed(
                                      '/take-photo-confirmation',
                                      arguments: lembrete?.id,
                                    );
                                    if (mounted) {
                                      _isLoopPaused = false;
                                    }
                                  } else {
                                    _isSpeakingLoopActive = false;
                                    if (lembrete != null) {
                                      LembreteService.instance
                                          .alternarConclusao(lembrete!.id)
                                          .catchError((e) {
                                            debugPrint(
                                              'Erro ao concluir lembrete: $e',
                                            );
                                          });
                                    }
                                    final feedbackMsg =
                                        lembrete?.categoria == 'hidratacao'
                                        ? 'Você bebeu sua água.'
                                        : lembrete?.categoria == 'refeicoes'
                                        ? 'Você fez sua refeição.'
                                        : lembrete?.categoria == 'exercicio'
                                        ? 'Você fez seu exercício.'
                                        : 'Você concluiu sua atividade.';
                                    navigator.pushNamedAndRemoveUntil(
                                      '/medication-confirmation',
                                      (route) => false,
                                      arguments: feedbackMsg,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_circle, size: 36),
                                label: Text(
                                  confirmButtonText,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.tertiaryFixedDim,
                                  foregroundColor: AppColors.onTertiaryFixed,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // BOTÃO ADIAR
                            SizedBox(
                              width: double.infinity,
                              height: 72,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _isSpeakingLoopActive = false;
                                  _isLoopPaused = false;
                                  VibrationService.stopVibration();
                                  TTSService.instance.parar();
                                  final navigator = Navigator.of(context);
                                  final categoria = lembrete?.categoria;
                                  if (lembrete != null) {
                                    NotificationService.instance
                                        .cancelar(lembrete!.id)
                                        .catchError((e) {
                                          debugPrint(
                                            'Erro ao cancelar notificacao: $e',
                                          );
                                        });
                                    LembreteService.instance
                                        .adiar(lembrete!.id, 10)
                                        .catchError((e) {
                                          debugPrint(
                                            'Erro ao adiar lembrete: $e',
                                          );
                                        });
                                  }
                                  navigator.pushNamedAndRemoveUntil(
                                    '/reinforcement-alert',
                                    (route) => false,
                                    arguments: {'categoria': categoria},
                                  );
                                },
                                icon: const Icon(Icons.access_time, size: 30),
                                label: const Text(
                                  'ME AVISE EM 10 MINUTOS',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondaryContainer,
                                  foregroundColor:
                                      AppColors.onSecondaryContainer,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 72,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _isSpeakingLoopActive = false;
                                  _isLoopPaused = false;
                                  VibrationService.stopVibration();
                                  TTSService.instance.parar();
                                  final navigator = Navigator.of(context);
                                  if (lembrete != null) {
                                    NotificationService.instance
                                        .cancelar(lembrete!.id)
                                        .catchError((e) {
                                          debugPrint(
                                            'Erro ao cancelar notificacao: $e',
                                          );
                                        });
                                    LembreteService.instance
                                        .registrarDificuldade(
                                          lembrete!.id,
                                          'O idoso informou que nao conseguiu realizar a atividade.',
                                        )
                                        .catchError((e) {
                                          debugPrint(
                                            'Erro ao registrar dificuldade: $e',
                                          );
                                        });
                                  }
                                  navigator.pushNamedAndRemoveUntil(
                                    '/reinforcement-alert',
                                    (route) => false,
                                    arguments: {
                                      'categoria': lembrete?.categoria,
                                      'tipo': 'dificuldade',
                                    },
                                  );
                                },
                                icon: const Icon(Icons.support_agent, size: 30),
                                label: const Text(
                                  'NÃO CONSEGUI FAZER',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: AppColors.onError,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: const Center(
        child: Text(
          'Lembrete Amigo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingMedication(IconData icon, Color color, Lembrete? l) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        // If it is a medication with custom photo, show the photo inside the pulsing ring
        if (l != null &&
            l.categoria == 'medicacao' &&
            l.medicamentoFotoPath != null)
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              image: DecorationImage(
                image: l.medicamentoFotoPath!.startsWith('assets/')
                    ? AssetImage(l.medicamentoFotoPath!) as ImageProvider
                    : FileImage(File(l.medicamentoFotoPath!)),
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Icon(icon, size: 68, color: Colors.white),
          ),
      ],
    );
  }
}
