import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../models/reminder_completion_result.dart';
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

    final isResumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _isLoopPaused = !isResumed;

    if (isResumed) {
      // Para o som do pacote alarm, pois a nossa tela já assumiu o controle e o TTS vai falar
      await Alarm.stopAll();
    }

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
    return Duration(minutes: l.toleranciaMinutos.clamp(1, 120));
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

  String _feedbackMessage(Lembrete reminder) {
    if (reminder.categoria == 'medicacao') {
      return 'Voce tomou seu remedio.';
    }
    if (reminder.categoria == 'hidratacao') return 'Voce bebeu sua agua.';
    if (reminder.categoria == 'refeicoes') return 'Voce comeu.';
    if (reminder.categoria == 'exercicio') {
      return 'Voce fez seu exercicio.';
    }
    return 'Voce concluiu sua atividade.';
  }

  void _stopReminderFeedback() {
    _isLoopPaused = true;
    VibrationService.stopVibration();
    AudioManager.stopAll();
    _noResponseTimer?.cancel();
    _urgencyReinforcementTimer?.cancel();
    _runInBackground(_familyAudioPlayer.stop(), 'parar audio');
    _runInBackground(TTSService.instance.parar(caller: this), 'parar tts');
  }

  Future<void> _handleConfirmation() async {
    final reminder = lembrete;
    if (reminder == null || !_tryStartAction()) return;
    try {
      final navigator = Navigator.of(context);
      _stopReminderFeedback();
      _runInBackground(
        NotificationService.instance.cancelar(reminder.id),
        'cancelar notificacao',
      );

      if (reminder.modoConfirmacao == LembreteModoConfirmacao.foto) {
        await navigator.pushNamed(
          '/take-photo-confirmation',
          arguments: reminder.id,
        );
        if (mounted) _isLoopPaused = false;
        return;
      }

      final result = await LembreteService.instance.confirmarOcorrencia(
        reminder.id,
        method: 'botao',
      );
      if (!mounted) return;
      if (result.outcome == ReminderCompletionOutcome.requiresCaregiver) {
        await LembreteService.instance.registrarDificuldade(
          reminder.id,
          'Esta atividade exige confirmacao do cuidador.',
        );
        if (!mounted) return;
        navigator.pushNamedAndRemoveUntil(
          '/reinforcement-alert',
          (route) => false,
          arguments: {'categoria': reminder.categoria, 'tipo': 'dificuldade'},
        );
        return;
      }
      if (!result.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.error,
          ),
        );
        _isLoopPaused = false;
        return;
      }

      _isSpeakingLoopActive = false;
      navigator.pushNamedAndRemoveUntil(
        '/medication-confirmation',
        (route) => false,
        arguments: {
          'message': _feedbackMessage(reminder),
          'reminderId': reminder.id,
          'registeredAt': result.registeredAt?.toIso8601String(),
          'duplicate':
              result.outcome == ReminderCompletionOutcome.alreadyCompleted,
        },
      );
    } catch (error) {
      debugPrint('Erro ao concluir lembrete: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nao consegui marcar como feito. Tente de novo.'),
            backgroundColor: AppColors.error,
          ),
        );
        _isLoopPaused = false;
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<int?> _chooseSnooze(Lembrete reminder) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quando devo lembrar de novo?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final minutes in reminder.opcoesAdiamentoMinutos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, minutes),
                    child: Text(
                      '$minutes minutos',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSnooze() async {
    final reminder = lembrete;
    if (reminder == null || !_tryStartAction()) return;
    try {
      if (!LembreteService.instance.podeAdiar(reminder.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'O limite de adiamentos acabou. Conclua ou peca ajuda.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final minutes = await _chooseSnooze(reminder);
      if (minutes == null || !mounted) return;
      _isSpeakingLoopActive = false;
      _isLoopPaused = false;
      _stopReminderFeedback();
      final ok = await LembreteService.instance.adiar(reminder.id, minutes);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nao consegui adiar este lembrete.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/reinforcement-alert',
        (route) => false,
        arguments: {'categoria': reminder.categoria, 'minutos': minutes},
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
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
        Alarm.stopAll();
        VibrationService.startVibration();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background — stop TTS and vibration
      setState(() {
        _isLoopPaused = true;
      });
      TTSService.instance.parar(caller: this);
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

  Future<void> _confirmLeaveReminder() async {
    if (_isProcessingAction || !mounted) return;
    setState(() => _isProcessingAction = true);
    try {
      final leave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
            size: 48,
          ),
          title: const Text(
            'Este lembrete ainda não foi concluído',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Você pode continuar nesta tela ou voltar ao início. O lembrete continuará pendente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Continuar lembrete'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      );

      if (leave != true || !mounted) return;
      _isSpeakingLoopActive = false;
      _isLoopPaused = false;
      _urgencyReinforcementTimer?.cancel();
      _noResponseTimer?.cancel();
      await VibrationService.stopVibration();
      await _familyAudioPlayer.stop();
      await TTSService.instance.parar(caller: this);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/elderly-home',
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
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
                Icon(Icons.error_outline, color: AppColors.error, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Lembrete não encontrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
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
      return Scaffold(
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
    final String confirmButtonText;

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
        unawaited(_confirmLeaveReminder());
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
                                    ? Border.all(
                                        color: AppColors.error,
                                        width: 4,
                                      )
                                    : Border.all(
                                        color: AppColors.error,
                                        width: 6,
                                      );

                                final shadow = isHighContrast
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.error.withValues(
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
                                    : _handleConfirmation,
                                icon: _isProcessingAction
                                    ? const SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle, size: 36),
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
                                      : AppColors.success,
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
                                onPressed:
                                    _isProcessingAction ||
                                        lembrete!.maximoAdiamentos == 0
                                    ? null
                                    : _handleSnooze,
                                icon: _isProcessingAction
                                    ? const SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          color: Colors.black54,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Icon(Icons.access_time, size: 30),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'LEMBRAR MAIS TARDE',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? AppColors.secondaryContainer
                                      : AppColors.secondaryContainer,
                                  foregroundColor: isHighContrast
                                      ? Colors.black
                                      : AppColors.onWarningContainer,
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
                                          final navigator = Navigator.of(
                                            context,
                                          );
                                          _isSpeakingLoopActive = false;
                                          _isLoopPaused = false;
                                          VibrationService.stopVibration();
                                          _runInBackground(
                                            _familyAudioPlayer.stop(),
                                            'parar audio',
                                          );
                                          _runInBackground(
                                            TTSService.instance.parar(
                                              caller: this,
                                            ),
                                            'parar tts',
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
                                              if (context.mounted) {
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
                                          if (context.mounted) {
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
                                      : AppColors.onSurfaceVariant,
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
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? AppColors.error
                                      : AppColors.error,
                                  disabledBackgroundColor:
                                      AppColors.outlineVariant,
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
                              Text(
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
