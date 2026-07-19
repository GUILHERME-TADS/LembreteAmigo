import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../services/notification_service.dart';
import '../services/vibration_service.dart';
import '../services/session_role_service.dart';
import '../utils/audio_path_helper.dart';
import '../utils/period_helper.dart';
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
  bool _notFound = false;
  bool _isSpeakingLoopActive = false;
  bool _isLoopPaused = false;
  bool _isFetchingReminder = false;
  final AudioPlayer _familyAudioPlayer = AudioPlayer();
  Timer? _urgencyReinforcementTimer;
  Timer? _noResponseTimer;
  bool _isProcessingAction = false;
  bool _isPaired = false;

  bool _tryStartAction() {
    if (_isProcessingAction || !mounted) return false;
    setState(() => _isProcessingAction = true);
    return true;
  }

  void _runInBackground(Future<void> future, String action) {
    unawaited(
      future.catchError((error, stackTrace) {
        debugPrint('Erro ao $action: $error');
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LembreteService.instance.carregar();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
    _loadPairedStatus();
  }

  Future<void> _loadPairedStatus() async {
    final connected = await SessionRoleService.isElderlyConnectedToSupervisor();
    if (mounted) {
      setState(() {
        _isPaired = connected;
      });
    }
  }

  void _onLembretesChanged() {
    unawaited(_buscarLembrete());
  }

  Future<void> _buscarLembrete() async {
    if (_lembreteId == null) return;
    final id = _lembreteId!;
    try {
      final match = LembreteService.instance.lembretes.where(
        (item) => item.id == id,
      );
      if (match.isEmpty) {
        if (_isFetchingReminder) return;
        _isFetchingReminder = true;
        final fetched = await LembreteService.instance.buscarPorId(id);
        _isFetchingReminder = false;
        if (!mounted || _lembreteId != id) return;
        if (fetched == null) {
          _returnToHomeAfterMissingReminder();
          return;
        }
        _setActiveReminder(fetched);
        return;
      }

      final l = match.first;
      if (l.concluido && lembrete != null) {
        _isSpeakingLoopActive = false;
        _isLoopPaused = false;
        _noResponseTimer?.cancel();
        _urgencyReinforcementTimer?.cancel();
        VibrationService.stopVibration();
        _familyAudioPlayer.stop();
        TTSService.instance.parar(caller: this);
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.pop(context);
        }
        return;
      }

      _setActiveReminder(l);
    } catch (e) {
      debugPrint('Erro ao buscar lembrete no ActiveReminderScreen: $e');
      _isFetchingReminder = false;
      if (mounted) {
        _returnToHomeAfterMissingReminder();
      }
    }
  }

  void _returnToHomeAfterMissingReminder() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/elderly-home',
        (route) => false,
      );
    });
  }

  void _setActiveReminder(Lembrete l) {
    if (!mounted) return;
    setState(() {
      lembrete = l;
      _notFound = false;
    });
    if (!_isSpeakingLoopActive) {
      _startReminderLoop(l);
    }
  }

  Future<void> _startReminderLoop(Lembrete l) async {
    if (_isSpeakingLoopActive) return;
    _isSpeakingLoopActive = true;
    _isLoopPaused = false;

    // Start parallel vibration loop
    _startVibrationLoop();

    // Critical reinforcement check only for medication category
    if (l.categoria == 'medicacao') {
      _urgencyReinforcementTimer = Timer(const Duration(minutes: 5), () async {
        if (mounted && _isSpeakingLoopActive && !l.concluido) {
          _isSpeakingLoopActive = false;
          VibrationService.stopVibration();

          await LembreteService.instance.registrarDificuldade(
            l.id,
            'ALERTA CRÍTICO: Idoso não respondeu ao lembrete crítico de medicação em 2 minutos. Reforço automático ativado.',
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
    _noResponseTimer?.cancel();
    _noResponseTimer = Timer(_noResponseLimit(l), () async {
      if (!mounted || !_isSpeakingLoopActive || l.concluido) return;
      await LembreteService.instance.registrarDificuldade(
        l.id,
        'Sem resposta do idoso depois de ${_noResponseLimit(l).inMinutes} minutos. O cuidador deve verificar se está tudo bem.',
      );
    });

    while (mounted && _isSpeakingLoopActive) {
      if (_isLoopPaused) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      if (l.medicamentoAudioTexto != null &&
          l.medicamentoAudioTexto!.isNotEmpty) {
        _speakText = l.medicamentoAudioTexto!;
      } else if (l.categoria == 'medicacao') {
        _speakText = 'Atenção! Hora do remédio: ${l.titulo}.';
      } else if (l.categoria == 'refeicoes') {
        _speakText = 'Atenção! Hora da refeição: ${l.titulo}.';
      } else if (l.categoria == 'hidratacao') {
        _speakText = 'Atenção! Hora da hidratação: ${l.titulo}.';
      } else if (l.categoria == 'exercicio') {
        _speakText = 'Atenção! Hora do exercício: ${l.titulo}.';
      } else {
        _speakText = 'Atenção! Hora do lembrete: ${l.titulo}.';
      }

      await _playFamilyAudioIfAvailable(l);
      if (!mounted || !_isSpeakingLoopActive || _isLoopPaused) continue;
      await TTSService.instance.falar(_speakText, caller: this);

      final waitSeconds = l.categoria == 'medicacao' ? 5 : 8;
      for (int i = 0; i < (waitSeconds * 10); i++) {
        if (!mounted || !_isSpeakingLoopActive || _isLoopPaused) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Duration _noResponseLimit(Lembrete l) {
    return const Duration(minutes: 5);
  }

  Future<void> _playFamilyAudioIfAvailable(Lembrete l) async {
    final path = l.audioPath;
    if (path == null || path.isEmpty || path == 'ia_generated') return;
    if (!await audioPathExists(path)) return;

    StreamSubscription? sub;
    try {
      AudioManager.stopAll();
      await TTSService.instance.parar(caller: this);
      await _familyAudioPlayer.stop();
      final completed = Completer<void>();
      sub = _familyAudioPlayer.onPlayerComplete.listen((_) {
        if (!completed.isCompleted) completed.complete();
      });
      await _familyAudioPlayer.play(audioSourceForPath(path), volume: 1.0);
      final audioDuration = await _familyAudioPlayer.getDuration();
      final safetySeconds = ((audioDuration?.inSeconds ?? 300) + 10).clamp(
        30,
        600,
      );
      await completed.future.timeout(
        Duration(seconds: safetySeconds),
        onTimeout: () async {
          if (mounted) {
            await _familyAudioPlayer.stop();
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao tocar voz familiar: $e');
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _startVibrationLoop() async {
    while (mounted && _isSpeakingLoopActive) {
      try {
        if (_isLoopPaused) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        await VibrationService.startVibration();
        await Future.delayed(const Duration(seconds: 4));
        await VibrationService.stopVibration();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('Erro no loop de vibracao: $e');
        await VibrationService.stopVibration();
        _isSpeakingLoopActive = false;
        break;
      }
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
      unawaited(_buscarLembrete());
    } else if (!_notFound) {
      setState(() => _notFound = true);
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



  @override
  void dispose() {
    _isSpeakingLoopActive = false;
    _isLoopPaused = false;
    _urgencyReinforcementTimer?.cancel();
    _noResponseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    VibrationService.stopVibration();
    _familyAudioPlayer.dispose();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Widget _buildMissingReminderScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lembrete não encontrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Não consegui abrir este lembrete. Volte para o início e tente de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/elderly-home',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text(
                      'VOLTAR AO INÍCIO',
                      style: TextStyle(
                        fontSize: 18,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) return _buildMissingReminderScaffold();
    if (lembrete == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final String titleText;
    final String subtitleText;
    final IconData categoryIcon;
    final Color iconColor;
    final bool requiresPhoto;
    final String confirmButtonText;

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
      confirmButtonText = 'JÁ TOMEI';
    } else if (lembrete!.categoria == 'refeicoes') {
      titleText = 'HORA DA REFEIÇÃO';
      subtitleText = 'Por favor, coma sua refeição agora.';
      confirmButtonText = 'JÁ COMI';
    } else if (lembrete!.categoria == 'hidratacao') {
      titleText = 'HORA DA HIDRATAÇÃO';
      subtitleText = 'Por favor, faça sua hidratação agora.';
      confirmButtonText = 'JÁ BEBI';
    } else if (lembrete!.categoria == 'exercicio') {
      titleText = 'HORA DO EXERCÍCIO';
      subtitleText = 'Por favor, faça seu exercício agora.';
      confirmButtonText = 'JÁ FIZ';
    } else {
      titleText = 'HORA DO LEMBRETE';
      subtitleText = 'Por favor, faça esta atividade agora.';
      confirmButtonText = 'JÁ FIZ';
    }

    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        TTSService.instance.parar();
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isHighContrast ? Colors.white : AppColors.background,
        floatingActionButton: AlexFloatingHelpButton(
          textoExplicacao:
              'Esta tela mostra o que você precisa fazer agora. Aperte $confirmButtonText quando terminar. Aperte DAQUI A POUCO para lembrar depois. Aperte PRECISO DE AJUDA se não conseguir.',
        ),
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
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 0,
                                color: isHighContrast
                                    ? Colors.black
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildPulsingMedication(
                              categoryIcon,
                              isHighContrast ? Colors.black : iconColor,
                              lembrete,
                            ),
                            const SizedBox(height: 32),
                            Builder(
                              builder: (context) {
                                final border = isHighContrast
                                    ? Border.all(color: Colors.red, width: 4)
                                    : Border.all(color: Colors.red, width: 6);

                                final shadow = isHighContrast
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.red.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ];

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: border,
                                    boxShadow: shadow,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            PeriodHelper.getPeriodIcon(
                                              lembrete!.horarioHour,
                                            ),
                                            color: isHighContrast
                                                ? Colors.black
                                                : PeriodHelper.getPeriodColor(
                                                    lembrete!.horarioHour,
                                                  ),
                                            size: 26,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'LEMBRETE DA ${PeriodHelper.getPeriodLabel(lembrete!.horarioHour).toUpperCase()}:',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0,
                                              color: isHighContrast
                                                  ? Colors.black
                                                  : PeriodHelper.getPeriodColor(
                                                      lembrete!.horarioHour,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        lembrete?.titulo ??
                                            'Carregando lembrete...',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: isHighContrast
                                              ? Colors.black
                                              : AppColors.primary,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        subtitleText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: isHighContrast
                                              ? Colors.black
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Play recorded audio if caregiver left a voice message
                            if (lembrete?.audioPath != null) ...[
                              AudioPlayerCard(
                                audioPath: lembrete!.audioPath == 'ia_generated'
                                    ? null
                                    : lembrete!.audioPath,
                                textsToSpeak:
                                    lembrete!.audioPath == 'ia_generated' &&
                                        lembrete!.medicamentoAudioTexto != null
                                    ? [lembrete!.medicamentoAudioTexto!]
                                    : null,
                                subtitle: lembrete!.audioPath == 'ia_generated'
                                    ? 'Alex explica o remédio'
                                    : 'Mensagem de voz do seu cuidador',
                              ),
                              const SizedBox(height: 24),
                            ],



                            // BOTAO CONFIRMAR (ENTENDI)
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessingAction
                                    ? null
                                    : () async {
                                        if (!_tryStartAction()) return;
                                        try {
                                          final navigator = Navigator.of(
                                            context,
                                          );
                                          _isLoopPaused = true;
                                          VibrationService.stopVibration();
                                          AudioManager.stopAll();
                                          _noResponseTimer?.cancel();
                                          await _familyAudioPlayer.stop();
                                          await TTSService.instance.parar();
                                          if (lembrete != null) {
                                            _runInBackground(
                                              NotificationService.instance
                                                  .cancelar(lembrete!.id),
                                              'cancelar notificacao',
                                            );
                                          }
                                          if (requiresPhoto) {
                                            final id = lembrete?.id;
                                            if (id == null || id.isEmpty) {
                                              if (mounted) {
                                                setState(
                                                  () => _notFound = true,
                                                );
                                              }
                                              return;
                                            }
                                            AudioManager.stopAll();
                                            await TTSService.instance.parar();
                                            await navigator.pushNamed(
                                              '/take-photo-confirmation',
                                              arguments: id,
                                            );
                                            if (mounted) {
                                              _isLoopPaused = false;
                                            }
                                          } else {
                                            if (lembrete != null) {
                                              try {
                                                final ok = await LembreteService
                                                    .instance
                                                    .alternarConclusao(
                                                      lembrete!.id,
                                                    );
                                                if (!ok) return;
                                                _isSpeakingLoopActive = false;
                                                final feedbackMsg =
                                                    lembrete?.categoria ==
                                                        'hidratacao'
                                                    ? 'Você bebeu sua água.'
                                                    : lembrete?.categoria ==
                                                          'refeicoes'
                                                    ? 'Você comeu.'
                                                    : lembrete?.categoria ==
                                                          'exercicio'
                                                    ? 'Você fez seu exercício.'
                                                    : 'Você concluiu sua atividade.';
                                                navigator
                                                    .pushNamedAndRemoveUntil(
                                                      '/medication-confirmation',
                                                      (route) => false,
                                                      arguments: feedbackMsg,
                                                    );
                                              } catch (e) {
                                                debugPrint(
                                                  'Erro ao concluir lembrete: $e',
                                                );
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Não consegui marcar como feito. Tente de novo.',
                                                      ),
                                                      backgroundColor:
                                                          AppColors.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _isProcessingAction = false,
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.check_circle, size: 36),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    confirmButtonText,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? Colors.black
                                      : const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  side: isHighContrast
                                      ? const BorderSide(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // BOTAO ADIAR
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessingAction
                                    ? null
                                    : () async {
                                        if (!_tryStartAction()) return;
                                        try {
                                          _isSpeakingLoopActive = false;
                                          _isLoopPaused = false;
                                          VibrationService.stopVibration();
                                          _noResponseTimer?.cancel();
                                          _familyAudioPlayer.stop();
                                          TTSService.instance.parar();
                                          final navigator = Navigator.of(
                                            context,
                                          );
                                          final categoria = lembrete?.categoria;
                                          if (lembrete != null) {
                                            try {
                                              final ok = await LembreteService
                                                  .instance
                                                  .adiar(lembrete!.id, 10);
                                              if (!ok) return;
                                              navigator.pushNamedAndRemoveUntil(
                                                '/reinforcement-alert',
                                                (route) => false,
                                                arguments: {
                                                  'categoria': categoria,
                                                },
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                'Erro ao adiar lembrete: $e',
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Não consegui lembrar depois. Tente de novo.',
                                                    ),
                                                    backgroundColor:
                                                        AppColors.error,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _isProcessingAction = false,
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.access_time, size: 30),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'DAQUI A POUCO (10 MINUTOS)',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? Colors.yellow
                                      : const Color(0xFFFFD54F),
                                  foregroundColor: isHighContrast
                                      ? Colors.black
                                      : const Color(0xFF5D4037),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  side: isHighContrast
                                      ? const BorderSide(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // BOTAO PRECISO DE AJUDA (Apenas se tiver ajudante conectado)
                            SizedBox(
                              width: double.infinity,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: _isPaired && !_isProcessingAction
                                    ? () async {
                                        if (!_tryStartAction()) return;
                                        try {
                                          _isSpeakingLoopActive = false;
                                          _isLoopPaused = false;
                                          VibrationService.stopVibration();
                                          await _familyAudioPlayer.stop();
                                          TTSService.instance.parar();
                                          final navigator = Navigator.of(
                                            context,
                                          );
                                          if (lembrete != null) {
                                            _runInBackground(
                                              NotificationService.instance
                                                  .cancelar(lembrete!.id),
                                              'cancelar notificacao',
                                            );
                                            try {
                                              final ok = await LembreteService
                                                  .instance
                                                  .registrarDificuldade(
                                                    lembrete!.id,
                                                    'O idoso informou que nao conseguiu realizar a atividade.',
                                                  );
                                              if (!ok) return;
                                              navigator.pushNamedAndRemoveUntil(
                                                '/reinforcement-alert',
                                                (route) => false,
                                                arguments: {
                                                  'categoria':
                                                      lembrete?.categoria,
                                                  'tipo': 'dificuldade',
                                                },
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                'Erro ao registrar dificuldade: $e',
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Não consegui pedir ajuda. Tente de novo.',
                                                    ),
                                                    backgroundColor:
                                                        AppColors.error,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _isProcessingAction = false,
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.support_agent,
                                  size: 30,
                                  color: _isPaired
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'PRECISO DE AJUDA',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _isPaired
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? Colors.red
                                      : const Color(0xFFD32F2F),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  elevation: _isPaired ? 4 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  side: isHighContrast && _isPaired
                                      ? const BorderSide(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (!_isPaired) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Precisa de um cuidador conectado para pedir ajuda',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
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
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: BoxDecoration(
        color: isHighContrast ? Colors.white : AppColors.surface,
        border: isHighContrast
            ? const Border(bottom: BorderSide(color: Colors.black, width: 2))
            : null,
      ),
      child: Center(
        child: Text(
          'Lembrete Amigo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isHighContrast ? Colors.black : AppColors.primary,
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
          width: 220,
          height: 220,
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
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
              image: DecorationImage(
                image: l.medicamentoFotoPath!.startsWith('assets/')
                    ? AssetImage(l.medicamentoFotoPath!) as ImageProvider
                    : isRemotePath(l.medicamentoFotoPath!)
                    ? NetworkImage(l.medicamentoFotoPath!)
                    : FileImage(File(l.medicamentoFotoPath!)),
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
            ),
            child: Icon(icon, size: 90, color: Colors.white),
          ),
      ],
    );
  }
}
