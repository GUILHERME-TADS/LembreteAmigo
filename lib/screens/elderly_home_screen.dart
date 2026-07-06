import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/location_service.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/audio_path_helper.dart';
import '../utils/period_helper.dart';
import '../widgets/index.dart';

class ElderlyHomeScreen extends StatefulWidget {
  final bool showConnected;
  final String? speakText;

  const ElderlyHomeScreen({
    super.key,
    this.showConnected = false,
    this.speakText,
  });

  @override
  State<ElderlyHomeScreen> createState() => _ElderlyHomeScreenState();
}

class _ElderlyHomeScreenState extends State<ElderlyHomeScreen>
    with TickerProviderStateMixin {
  bool _isConnected = false;
  List<Lembrete> _lembretes = [];
  Lembrete? _ultimoLembrete;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _playingAudioPath;
  bool _isBannerSpeaking = false;
  bool _isOnline = true;
  Timer? _connectivityTimer;
  StreamSubscription? _audioSubscription;

  // Confetti Animations
  AnimationController? _confettiController;
  final List<_ConfettiParticle> _confetti = [];
  bool _allCompletedTriggered = false;
  bool _rotinaDoDiaOnly = false;
  bool _showWelfareCheckin = false;
  bool _isProcessingAction = false;
  int _welfareStep = 0;
  String _selectedMood = '';
  bool _hasSpokenWelfareGreeting = false;
  String _idosoNomeCheckin = 'João';
  String? _fotoPath;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  Future<void> _updateConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pairedIdosoId = prefs.getString('paired_idoso_id');
    if (mounted) {
      setState(() {
        _isConnected = pairedIdosoId != null && pairedIdosoId != 'idoso_autonomo';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isConnected = widget.showConnected;
    _updateConnectionStatus();
    _checkConnection();
    _loadProfilePhoto();
    if (widget.speakText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TTSService.instance.falar(widget.speakText!, caller: this);
      });
    }
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnection(),
    );

    // Pulse Controller Setup
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    // Confetti Controller Setup
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _confettiController!.addListener(() {
      if (mounted) {
        setState(() {
          for (final p in _confetti) {
            p.y += p.vy;
            p.x += p.vx;
            p.rotation += p.rotationSpeed;
          }
        });
      }
    });

    LembreteService.instance.carregar().then((_) {
      final lembretes = LembreteService.instance.lembretes;
      if (mounted) {
        setState(() {
          _lembretes = lembretes
              .where((l) => _isReminderActiveToday(l))
              .toList();
          _atualizarProximoLembrete();
          _checkVictoryConfetti();
          _checkWelfareStatus();
        });
      }
    });
    LembreteService.instance.notifier.addListener(_onLembretesChanged);

    _audioSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingAudioPath = null;
        });
      }
    });
  }

  void _onLembretesChanged() {
    final lembretes = LembreteService.instance.lembretes;
    if (mounted) {
      setState(() {
        _lembretes = lembretes.where((l) => _isReminderActiveToday(l)).toList();
        _atualizarProximoLembrete();
        _checkVictoryConfetti();
      });
    }
  }

  void _checkVictoryConfetti() async {
    if (mounted) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        return;
      }
    }

    final allDone =
        _lembretes.isNotEmpty && _lembretes.every((l) => l.concluido);
    if (allDone && !_allCompletedTriggered) {
      _allCompletedTriggered = true;

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Evita disparar a mensagem de parabéns múltiplas vezes no mesmo dia
      final lastVictory = prefs.getString('last_victory_shown_date');
      if (lastVictory == today) {
        return;
      }

      final lastCompletion = prefs.getString('last_completion_date');
      int streak = prefs.getInt('completion_streak') ?? 0;

      if (lastCompletion != today) {
        if (lastCompletion ==
            DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String()
                .substring(0, 10)) {
          streak += 1;
        } else {
          streak = 1;
        }
        await prefs.setInt('completion_streak', streak);
        await prefs.setString('last_completion_date', today);
      }

      await prefs.setString('last_victory_shown_date', today);

      _startConfetti();
      _showVictoryDialog(streak);
    } else if (!allDone) {
      _allCompletedTriggered = false;

      // Se desmarcar alguma tarefa, permite ganhar os parabéns novamente caso conclua tudo
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (prefs.getString('last_victory_shown_date') == today) {
        await prefs.remove('last_victory_shown_date');
      }
    }
  }

  void _startConfetti() {
    final random = math.Random();
    _confetti.clear();
    for (int i = 0; i < 80; i++) {
      _confetti.add(
        _ConfettiParticle(
          x: random.nextDouble() * 400,
          y: -random.nextDouble() * 200,
          vx: (random.nextDouble() - 0.5) * 4,
          vy: random.nextDouble() * 5 + 3,
          size: random.nextDouble() * 10 + 6,
          color: [
            Colors.redAccent,
            Colors.blueAccent,
            Colors.greenAccent,
            Colors.yellowAccent,
            Colors.orangeAccent,
            Colors.pinkAccent,
            Colors.purpleAccent,
          ][random.nextInt(7)],
          rotation: random.nextDouble() * math.pi,
          rotationSpeed: (random.nextDouble() - 0.5) * 0.1,
        ),
      );
    }
    _confettiController?.forward(from: 0.0);
  }

  void _atualizarProximoLembrete() {
    if (_lembretes.isEmpty) {
      _ultimoLembrete = null;
      return;
    }
    final agora = TimeOfDay.now();
    final agoraMinutos = agora.hour * 60 + agora.minute;

    final lembretesOrdenados = List<Lembrete>.from(_lembretes)
      ..sort((a, b) {
        final aMin = a.horarioHour * 60 + a.horarioMinute;
        final bMin = b.horarioHour * 60 + b.horarioMinute;
        return aMin.compareTo(bMin);
      });

    Lembrete? proximo;
    for (final l in lembretesOrdenados) {
      final lMin = l.horarioHour * 60 + l.horarioMinute;
      if (!l.concluido && lMin >= agoraMinutos) {
        proximo = l;
        break;
      }
    }

    if (proximo == null) {
      for (final l in lembretesOrdenados) {
        if (!l.concluido) {
          proximo = l;
          break;
        }
      }
    }

    _ultimoLembrete = proximo ?? lembretesOrdenados.last;
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _confettiController?.dispose();
    _pulseController?.dispose();
    _audioSubscription?.cancel();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    TTSService.instance.parar(caller: this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkWelfareStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastCheckin = prefs.getString('last_welfare_checkin_date');

    final jsonStr = prefs.getString('idoso_perfil');
    String name = '';
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr);
        final rawName = data['nome']?.toString() ?? '';
        if (rawName.isNotEmpty &&
            rawName != 'Minha Conta' &&
            rawName != 'Não cadastrado' &&
            rawName != 'Minha' &&
            rawName != 'Não') {
          name = rawName.split(' ').first;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _idosoNomeCheckin = name;
        _showWelfareCheckin = (lastCheckin != today);
      });

      if (_showWelfareCheckin && !_hasSpokenWelfareGreeting) {
        _hasSpokenWelfareGreeting = true;
        final greetingText = _idosoNomeCheckin.trim().isEmpty
            ? 'Como você está hoje? Selecione uma das opções na tela.'
            : '$_idosoNomeCheckin, como você está hoje? Selecione uma das opções na tela.';
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _showWelfareCheckin && _welfareStep == 0) {
            TTSService.instance.falar(greetingText, caller: this);
          }
        });
      }
    }
  }

  Future<void> _registrarWelfareCheckin(String emotion, {String? detail}) async {
    if ((emotion == 'Mais ou menos' || emotion == 'Preciso de ajuda') && detail == null) {
      if (mounted) {
        setState(() {
          _selectedMood = emotion;
          _welfareStep = 1;
        });
      }
      final detailQuestion = emotion == 'Preciso de ajuda'
          ? 'O que está acontecendo? Selecione uma das opções na tela.'
          : 'O que você está sentindo? Selecione uma das opções na tela.';
      await TTSService.instance.falar(detailQuestion, caller: this);
      return;
    }

    final String welfareText = detail != null ? '$emotion - $detail' : emotion;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_welfare_checkin_date', today);
    await LembreteService.instance.registrarWelfareCheckin(welfareText);
    if (!mounted) return;
    setState(() {
      _welfareStep = 2;
    });

    String feedbackSpeech = 'Obrigado por me contar. Já avisei seu cuidador.';
    await TTSService.instance.falar(feedbackSpeech, caller: this);

    Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        setState(() {
          _showWelfareCheckin = false;
          _welfareStep = 0;
          _selectedMood = '';
        });
      }
    });
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFoto = prefs.getString('idoso_foto_path');
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto no home: $e');
    }
  }

  String _tempoRestante(Lembrete lembrete) {
    final now = DateTime.now();
    var targetTime = DateTime(
      now.year,
      now.month,
      now.day,
      lembrete.horarioHour,
      lembrete.horarioMinute,
    );

    // Se o horário programado para hoje já passou E o lembrete foi criado depois disso hoje,
    // a próxima ocorrência é amanhã (ou próximo dia recorrente).
    if (targetTime.isBefore(now) && lembrete.criadoEm.isAfter(targetTime)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    var diff = targetTime.difference(now);
    if (diff.isNegative) {
      if (diff.inMinutes.abs() < 5) {
        return 'Agora mesmo';
      }
      return 'Atrasado';
    }

    if (diff.inHours > 0) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (minutes > 0) {
        return 'Daqui a $hours ${hours == 1 ? 'hora' : 'horas'} e $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
      }
      return 'Daqui a $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else {
      final minutes = diff.inMinutes;
      if (minutes == 0) {
        return 'Agora mesmo';
      }
      return 'Daqui a $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    }
  }

  bool _isReminderActiveToday(Lembrete lembrete) {
    final now = DateTime.now();
    if (lembrete.recorrencia == 'diario' || lembrete.repeteTodosOsDias) {
      return true;
    }
    if (lembrete.recorrencia == 'semanal' || lembrete.recorrenciaSemanal) {
      return lembrete.diasSemana.contains(now.weekday);
    }
    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      return (lembrete.diaMes ?? lembrete.criadoEm.day) == now.day;
    }
    if (lembrete.recorrencia == 'quinzenal') {
      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(
            DateTime(
              lembrete.criadoEm.year,
              lembrete.criadoEm.month,
              lembrete.criadoEm.day,
            ),
          )
          .inDays;
      return diffDays >= 0 && diffDays % 15 == 0;
    }
    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      final hojeKey = '${now.year}-${now.month}-${now.day}';
      final criadoKey =
          '${lembrete.criadoEm.year}-${lembrete.criadoEm.month}-${lembrete.criadoEm.day}';
      return hojeKey == criadoKey;
    }
    if (lembrete.recorrencia == 'intervalo' || lembrete.recorrenciaIntervalo) {
      return true;
    }
    return true;
  }

  void _ouvirExplicacaoLembrete(Lembrete l) {
    _stopAllAudioAndTts();
    final remaining = _tempoRestante(l);
    final isLembreteAtrasado =
        !l.concluido &&
        l.status != LembreteStatus.adiado &&
        remaining == 'Atrasado';

    final spokenTime = PeriodHelper.getSpokenTime(
      l.horarioHour,
      l.horarioMinute,
    );

    String text = '';

    if (l.concluido) {
      text =
          'O lembrete ${l.titulo}, marcado para às $spokenTime, já está pronto e feito! Muito bem!';
    } else if (l.status == LembreteStatus.adiado) {
      text = 'O lembrete ${l.titulo} ficou para mais tarde, às $spokenTime.';
    } else if (l.status == LembreteStatus.perdido) {
      text =
          'Este lembrete era para às $spokenTime, mas o tempo passou e não deu para fazer.';
    } else if (remaining == 'Agora mesmo') {
      text =
          'Chegou a hora de fazer ${l.titulo}! O horário marcado é às $spokenTime.';
    } else if (isLembreteAtrasado) {
      text =
          'O lembrete ${l.titulo} passou da hora! O horário era às $spokenTime.';
    } else {
      final remainingClean = remaining.replaceAll('Daqui a ', '');
      text =
          'O lembrete ${l.titulo} está marcado para às $spokenTime. Ainda falta $remainingClean para dar o horário.';
    }

    if (l.categoria == 'medicacao' &&
        l.medicamentoForma != null &&
        l.medicamentoCor != null) {
      final formaLabel = l.medicamentoForma == 'capsula'
          ? 'cápsula'
          : l.medicamentoForma == 'comprimido'
          ? 'comprimido'
          : l.medicamentoForma == 'gotas'
          ? 'gotas'
          : 'pomada';
      text += ' É um remédio do tipo $formaLabel na cor ${l.medicamentoCor}.';
    }

    TTSService.instance.falar(text, caller: this);
  }

  Widget _buildSOSFAB() {
    return FloatingActionButton.extended(
      onPressed: _showSOSModal,
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.emergency, size: 28),
      label: const Text(
        'SOS',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  void _confirmarAcaoSOSComContagem(
    String acaoTitulo,
    String ttsMensagem,
    VoidCallback acaoConfirmada,
  ) {
    _stopAllAudioAndTts();

    int segundosRestantes = 5;
    Timer? countdownTimer;

    TTSService.instance.falar(
      '$ttsMensagem em $segundosRestantes segundos. Aperte no botão para cancelar.',
      caller: this,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isHighContrast =
            Theme.of(context).colorScheme.primary == Colors.black;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (segundosRestantes > 1) {
                if (mounted) {
                  setDialogState(() {
                    segundosRestantes--;
                  });
                  TTSService.instance.falar('$segundosRestantes', caller: this);
                }
              } else {
                timer.cancel();
                Navigator.pop(context); // Fechar o diálogo
                acaoConfirmada(); // Executar a ação
              }
            });

            return AlertDialog(
              backgroundColor: isHighContrast
                  ? Colors.white
                  : AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: isHighContrast
                    ? const BorderSide(color: Colors.black, width: 4)
                    : BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.warning, color: AppColors.error, size: 36),
                      SizedBox(width: 12),
                      Text(
                        'ATENÇÃO',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    acaoTitulo.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isHighContrast ? Colors.black : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.error, width: 4),
                    ),
                    child: Center(
                      child: Text(
                        '$segundosRestantes',
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'O telefone fará a ação automaticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        countdownTimer?.cancel();
                        TTSService.instance.parar(caller: this);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, size: 36),
                      label: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHighContrast
                            ? Colors.black
                            : AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isHighContrast
                              ? const BorderSide(color: Colors.white, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
    });
  }

  void _showSOSModal() async {
    final prefs = await SharedPreferences.getInstance();
    final idosoId =
        prefs.getString('paired_idoso_id') ??
        SessionRoleService.unpairedIdosoId;

    String phone = '';
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();
        if (doc.exists) {
          phone = doc.data()?['telefone'] ?? '';
        }
      }
    } catch (_) {}

    if (phone.isEmpty) {
      phone = prefs.getString('emergency_contact_phone') ?? '190';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isHighContrast =
            Theme.of(context).colorScheme.primary == Colors.black;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: isHighContrast
                ? const Border(
                    top: BorderSide(color: Colors.black, width: 4),
                    left: BorderSide(color: Colors.black, width: 4),
                    right: BorderSide(color: Colors.black, width: 4),
                  )
                : null,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isHighContrast)
                  Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: AppColors.error, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'SOS - EMERGÊNCIA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isHighContrast ? Colors.black : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecione uma opção de socorro imediato:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isHighContrast
                        ? Colors.black
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarAcaoSOSComContagem(
                        'Ligar para Ajudante',
                        'Iniciando ligação para o ajudante',
                        () => _ligar(phone),
                      );
                    },
                    icon: const Icon(Icons.person, size: 28),
                    label: const Text(
                      'LIGAR PARA AJUDANTE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast
                          ? Colors.black
                          : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isHighContrast
                            ? const BorderSide(color: Colors.black, width: 2)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarAcaoSOSComContagem(
                        'Ligar para SAMU',
                        'Iniciando ligação para o SAMU no 1 9 2',
                        () => _ligar('192'),
                      );
                    },
                    icon: const Icon(Icons.local_hospital, size: 28),
                    label: const Text(
                      'LIGAR PARA SAMU (192)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast
                          ? Colors.black
                          : AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isHighContrast
                            ? const BorderSide(color: Colors.black, width: 2)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarAcaoSOSComContagem(
                        'Enviar Localização',
                        'Enviando sua localização para o ajudante',
                        () => _enviarSMSLocalizacao(phone),
                      );
                    },
                    icon: const Icon(Icons.location_on, size: 28),
                    label: const Text(
                      'ENVIAR SMS COM LOCALIZAÇÃO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast
                          ? Colors.black
                          : Colors.white,
                      foregroundColor: isHighContrast
                          ? Colors.white
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isHighContrast
                              ? Colors.black
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _ligar(String numero) async {
    final Uri launchUri = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o discador.')),
        );
      }
    }
  }

  void _enviarSMSLocalizacao(String supervisorPhone) async {
    TTSService.instance.falar(
      'Estou buscando sua localizacao para enviar o pedido de ajuda.',
      caller: this,
    );

    final location = await LocationService.instance.getCurrentSosLocation();
    final message = location.hasLocation
        ? 'SOS! Preciso de ajuda urgente. Minha localizacao: ${location.mapsUrl}'
        : 'SOS! Preciso de ajuda urgente. Nao consegui enviar minha localizacao automaticamente. ${location.errorMessage ?? ''}';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: supervisorPhone,
      queryParameters: <String, String>{'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      const feedback =
          'O aplicativo de mensagens foi aberto. Toque em enviar para concluir o pedido de ajuda.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(feedback)));
      }
      TTSService.instance.falar(feedback, caller: this);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              location.hasLocation
                  ? 'Nao foi possivel abrir o SMS com a localizacao.'
                  : 'Nao foi possivel abrir o SMS. ${location.errorMessage ?? ''}',
            ),
          ),
        );
        TTSService.instance.falar(
          'Nao foi possivel abrir o aplicativo de mensagens.',
          caller: this,
        );
      }
    }
  }

  void _showVictoryDialog(int streak) {
    TTSService.instance.falar(
      'Parabéns! Você concluiu toda a sua rotina de hoje! Continue assim para manter sua saúde excelente!',
      caller: this,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: const [
              Icon(Icons.emoji_events, color: Colors.amber, size: 36),
              SizedBox(width: 12),
              Text(
                'Parabéns!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Você completou todos os seus lembretes de hoje!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 36,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sequência: $streak ${streak == 1 ? 'dia' : 'dias'}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiaryFixedDim,
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.onTertiaryFixed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRotinaToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _rotinaDoDiaOnly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_rotinaDoDiaOnly
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Rotina Completa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: !_rotinaDoDiaOnly
                        ? Colors.white
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _rotinaDoDiaOnly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _rotinaDoDiaOnly
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'O Que Falta Hoje',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _rotinaDoDiaOnly
                        ? Colors.white
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelfareCheckinCard() {
    if (_welfareStep == 2) {
      return _buildConfirmationStep();
    }
    if (_welfareStep == 1) {
      return _buildDetailStep();
    }
    return _buildMoodStep();
  }

  Widget _buildMoodStep() {
    final greetingText = _idosoNomeCheckin.trim().isEmpty
        ? 'Como você está hoje?'
        : '$_idosoNomeCheckin, como você está hoje?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryFixedDim, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  greetingText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onPrimaryFixed,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
                onPressed: () {
                  final textToSpeak = _idosoNomeCheckin.trim().isEmpty
                      ? 'Como você está hoje? Selecione uma das opções abaixo.'
                      : '$_idosoNomeCheckin, como você está hoje? Selecione uma das opções abaixo.';
                  TTSService.instance.falar(textToSpeak, caller: this);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _welfareOption('Bem', '😊', Colors.green.shade100, Colors.green.shade800),
              const SizedBox(width: 8),
              _welfareOption('Mais ou menos', '😐', Colors.orange.shade100, Colors.orange.shade800),
              const SizedBox(width: 8),
              _welfareOption('Preciso de ajuda', '🆘', Colors.red.shade100, Colors.red.shade900),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welfareOption(String label, String emoji, Color btnBgColor, Color btnTextColor) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _registrarWelfareCheckin(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnBgColor,
          foregroundColor: btnTextColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: btnTextColor.withValues(alpha: 0.3), width: 2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: btnTextColor,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStep() {
    final titleText = _selectedMood == 'Preciso de ajuda'
        ? 'O que está acontecendo?'
        : 'O que você está sentindo?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryFixedDim, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onPrimaryFixed,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
                onPressed: () {
                  final textToSpeak = _selectedMood == 'Preciso de ajuda'
                      ? 'O que está acontecendo? Selecione uma das opções: dor física, tristeza ou solidão, cansaço ou outro motivo.'
                      : 'O que você está sentindo? Selecione uma das opções: dor física, tristeza ou solidão, cansaço ou outro motivo.';
                  TTSService.instance.falar(textToSpeak, caller: this);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailOption('Dor física', '🩹'),
          const SizedBox(height: 8),
          _detailOption('Tristeza / Solidão', '😢'),
          const SizedBox(height: 8),
          _detailOption('Cansaço', '🥱'),
          const SizedBox(height: 8),
          _detailOption('Outro motivo', '❓'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _welfareStep = 0;
                    _selectedMood = '';
                  });
                }
              },
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              label: const Text(
                'Voltar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailOption(String label, String emoji) {
    return ElevatedButton(
      onPressed: () => _registrarWelfareCheckin(_selectedMood, detail: label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryFixedDim, width: 2),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade700,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Check-in Enviado!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Obrigado por responder. Seu cuidador já foi avisado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkConnection() async {
    if (kIsWeb) {
      if (mounted && !_isOnline) {
        setState(() {
          _isOnline = true;
        });
      }
      return;
    }
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      final bool hasNet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != hasNet) {
        setState(() {
          _isOnline = hasNet;
        });
      }
    } catch (_) {
      if (mounted && _isOnline) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  void _stopAllAudioAndTts() {
    if (_isPlaying) {
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingAudioPath = null;
      });
    }
    TTSService.instance.parar(caller: this);
    setState(() {
      _isBannerSpeaking = false;
    });
  }

  Future<void> _abrirGravacao() async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      _stopAllAudioAndTts();
      final result = await Navigator.pushNamed(context, '/recording-audio');
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lembrete criado com sucesso!'),
            backgroundColor: AppColors.tertiaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  void _playAudio(String path) async {
    if (_isBannerSpeaking) {
      await TTSService.instance.parar(caller: this);
      if (mounted) setState(() => _isBannerSpeaking = false);
    }

    if (_isPlaying) {
      _audioPlayer.stop();
      if (_playingAudioPath == path) {
        setState(() {
          _isPlaying = false;
          _playingAudioPath = null;
        });
        return;
      }
    }

    setState(() {
      _isPlaying = true;
      _playingAudioPath = path;
    });
    _playAudioAsync(path);
  }

  void _playAudioAsync(String path) async {
    try {
      await _audioPlayer.play(audioSourceForPath(path));
    } catch (e) {
      debugPrint('Erro ao reproduzir áudio local: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingAudioPath = null;
        });
      }
    }
  }

  void _speakReminder(Lembrete l) async {
    if (_isPlaying) {
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingAudioPath = null;
      });
    }

    if (_isBannerSpeaking) {
      TTSService.instance.parar(caller: this);
      setState(() => _isBannerSpeaking = false);
      return;
    }

    setState(() => _isBannerSpeaking = true);
    final text = _descreverLembrete(l);
    await TTSService.instance.falar(text, caller: this);
    if (mounted) setState(() => _isBannerSpeaking = false);
  }


  String _descreverLembrete(Lembrete l) {
    final spokenTime = PeriodHelper.getSpokenTime(
      l.horarioHour,
      l.horarioMinute,
    );
    return '${l.titulo} às $spokenTime.';
  }

  Widget _buildNode(Lembrete lembrete) {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    final bool isMed = lembrete.categoria == 'medicacao';
    Color bg;
    IconData? icon;
    Color iconColor = isHighContrast ? Colors.black : Colors.white;

    if (lembrete.concluido) {
      bg = isHighContrast ? Colors.black : AppColors.tertiaryFixedDim;
      iconColor = Colors.white;
    } else {
      if (isHighContrast) {
        bg = Colors.white;
      } else {
        switch (lembrete.categoria) {
          case 'medicacao':
            bg = AppColors.medicationsColor;
            break;
          case 'refeicoes':
            bg = AppColors.mealsColor;
            break;
          case 'exercicio':
            bg = AppColors.tertiaryContainer;
            break;
          case 'hidratacao':
            bg = AppColors.voiceFeedbackBlue;
            break;
          default:
            bg = AppColors.customColor;
        }
      }
    }

    if (!isMed) {
      switch (lembrete.categoria) {
        case 'refeicoes':
          icon = Icons.restaurant;
          break;
        case 'exercicio':
          icon = Icons.directions_walk;
          break;
        case 'hidratacao':
          icon = Icons.water_drop;
          break;
        default:
          icon = Icons.notifications;
      }
    }

    const double nodeSize = 64.0;
    Widget innerWidget;
    if (isMed) {
      innerWidget = Center(
        child: PillVisualizer(
          forma: lembrete.medicamentoForma,
          cor: lembrete.medicamentoCor,
          size: 40.0,
          fotoPath: lembrete.medicamentoFotoPath,
        ),
      );
    } else {
      innerWidget = Icon(icon, size: 32.0, color: iconColor);
    }

    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: isHighContrast
              ? Colors.black
              : (lembrete.concluido
                    ? AppColors.onTertiaryFixedVariant
                    : Colors.white),
          width: 3,
        ),
        boxShadow: isHighContrast
            ? null
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          innerWidget,
          if (lembrete.concluido)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? Colors.black
                      : const Color(0xFF005312),
                  shape: BoxShape.circle,
                  border: isHighContrast
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Lembrete lembrete) {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    final isMed = lembrete.categoria == 'medicacao';
    final statusText = _statusText(lembrete);
    final isAtrasado =
        !lembrete.concluido &&
        lembrete.status != LembreteStatus.adiado &&
        _tempoRestante(lembrete) == 'Atrasado';
    String subtitle = '';

    Color accentColor = AppColors.primary;
    if (lembrete.categoria == 'medicacao') {
      accentColor = AppColors.medicationsColor;
    } else if (lembrete.categoria == 'refeicoes') {
      accentColor = AppColors.mealsColor;
    } else if (lembrete.categoria == 'exercicio') {
      accentColor = AppColors.tertiaryContainer;
    } else if (lembrete.categoria == 'hidratacao') {
      accentColor = AppColors.voiceFeedbackBlue;
    } else {
      accentColor = AppColors.customColor;
    }
    if (isMed &&
        lembrete.medicamentoForma != null &&
        lembrete.medicamentoCor != null) {
      final formaLabel = lembrete.medicamentoForma == 'capsula'
          ? 'Cápsula'
          : lembrete.medicamentoForma == 'comprimido'
          ? 'Comprimido'
          : lembrete.medicamentoForma == 'gotas'
          ? 'Gotas'
          : 'Pomada';
      subtitle = '$formaLabel ${lembrete.medicamentoCor}';
    } else {
      subtitle = statusText;
    }

    final cardBg = isHighContrast
        ? Colors.white
        : (lembrete.concluido
              ? const Color(0xFFE8F5E9)
              : lembrete.status == LembreteStatus.adiado
              ? const Color(0xFFFFFDE7)
              : isAtrasado
              ? const Color(0xFFFFEBEE)
              : AppColors.surfaceContainerLowest);

    final titleColor = isHighContrast
        ? Colors.black
        : (lembrete.concluido
              ? AppColors.onTertiaryFixedVariant
              : lembrete.status == LembreteStatus.adiado
              ? AppColors.onSecondaryFixedVariant
              : accentColor);

    final String barText = lembrete.concluido
        ? 'PRONTO!'
        : lembrete.status == LembreteStatus.adiado
        ? 'MAIS TARDE'
        : lembrete.status == LembreteStatus.perdido
        ? 'NÃO DEU'
        : isAtrasado
        ? 'PASSOU DA HORA'
        : 'FALTA FAZER';

    final IconData barIcon = lembrete.concluido
        ? Icons.check_circle
        : lembrete.status == LembreteStatus.adiado
        ? Icons.schedule
        : lembrete.status == LembreteStatus.perdido
        ? Icons.cancel_outlined
        : isAtrasado
        ? Icons.priority_high
        : Icons.info_outline;

    final Color barBg = isHighContrast
        ? (lembrete.concluido
              ? Colors.black
              : lembrete.status == LembreteStatus.adiado
              ? Colors.yellow
              : (isAtrasado || lembrete.status == LembreteStatus.perdido)
              ? Colors.red
              : Colors.black)
        : (lembrete.concluido
              ? AppColors.tertiaryFixedDim
              : lembrete.status == LembreteStatus.adiado
              ? AppColors.secondaryFixed
              : (isAtrasado || lembrete.status == LembreteStatus.perdido)
              ? AppColors.error
              : accentColor);

    final Color barFg = isHighContrast
        ? (lembrete.status == LembreteStatus.adiado
              ? Colors.black
              : Colors.white)
        : (lembrete.concluido
              ? AppColors.onTertiaryFixedVariant
              : lembrete.status == LembreteStatus.adiado
              ? AppColors.onSecondaryFixedVariant
              : (isAtrasado || lembrete.status == LembreteStatus.perdido)
              ? AppColors.onError
              : Colors.white);

    return Card(
      elevation: isHighContrast ? 0 : 2,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighContrast
              ? (isAtrasado ? Colors.red : Colors.black)
              : (lembrete.concluido
                    ? AppColors.tertiaryFixedDim
                    : lembrete.status == LembreteStatus.adiado
                    ? AppColors.secondaryFixedDim
                    : isAtrasado
                    ? AppColors.error
                    : accentColor),
          width: isHighContrast ? (isAtrasado ? 4 : 3) : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (lembrete.audioPath != null) {
            _playAudio(lembrete.audioPath!);
          } else {
            _speakReminder(lembrete);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lembrete.titulo,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            decoration: lembrete.concluido
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (subtitle != statusText) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isHighContrast
                                  ? Colors.black
                                  : (lembrete.status == LembreteStatus.adiado
                                        ? AppColors.onSecondaryFixedVariant
                                        : AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  if (lembrete.audioPath != null) ...[
                    GestureDetector(
                      onTap: () => _playAudio(lembrete.audioPath!),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color:
                              _isPlaying &&
                                  _playingAudioPath == lembrete.audioPath
                              ? (isHighContrast
                                    ? Colors.yellow
                                    : (lembrete.status == LembreteStatus.adiado
                                          ? AppColors.secondaryFixed
                                          : accentColor.withValues(alpha: 0.2)))
                              : (isHighContrast
                                    ? Colors.white
                                    : accentColor.withValues(alpha: 0.1)),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHighContrast
                                ? Colors.black
                                : (lembrete.status == LembreteStatus.adiado
                                      ? AppColors.onSecondaryFixedVariant
                                      : accentColor),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          _isPlaying && _playingAudioPath == lembrete.audioPath
                              ? Icons.stop
                              : Icons.play_arrow,
                          color: isHighContrast
                              ? Colors.black
                              : (lembrete.status == LembreteStatus.adiado
                                    ? AppColors.onSecondaryFixedVariant
                                    : accentColor),
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                  GestureDetector(
                    onTap: () async {
                      if (_isProcessingAction) return;
                      setState(() => _isProcessingAction = true);
                      try {
                        if (isMed && !lembrete.concluido) {
                          await Navigator.pushNamed(
                            context,
                            '/take-photo-confirmation',
                            arguments: lembrete.id,
                          );
                        } else {
                          await LembreteService.instance.alternarConclusao(lembrete.id);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessingAction = false);
                        }
                      }
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: lembrete.concluido
                            ? (isHighContrast
                                  ? Colors.black
                                  : AppColors.tertiaryFixedDim)
                            : lembrete.status == LembreteStatus.adiado
                            ? (isHighContrast
                                  ? Colors.yellow
                                  : AppColors.secondaryFixed)
                            : (isAtrasado ||
                                  lembrete.status == LembreteStatus.perdido)
                            ? (isHighContrast ? Colors.red : AppColors.error)
                            : (isHighContrast
                                  ? Colors.white
                                  : accentColor.withValues(alpha: 0.1)),
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isHighContrast
                              ? Colors.black
                              : (lembrete.concluido
                                    ? AppColors.onTertiaryFixedVariant
                                    : lembrete.status == LembreteStatus.adiado
                                    ? AppColors.onSecondaryFixedVariant
                                    : (isAtrasado ||
                                          lembrete.status ==
                                              LembreteStatus.perdido)
                                    ? AppColors.onError
                                    : accentColor),
                          width: 3,
                        ),
                      ),
                      child:
                          lembrete.concluido ||
                              lembrete.status == LembreteStatus.adiado ||
                              isAtrasado ||
                              lembrete.status == LembreteStatus.perdido
                          ? Icon(
                              lembrete.concluido
                                  ? Icons.check
                                  : lembrete.status == LembreteStatus.adiado
                                  ? Icons.schedule
                                  : lembrete.status == LembreteStatus.perdido
                                  ? Icons.close
                                  : Icons.priority_high,
                              color: lembrete.concluido
                                  ? (isHighContrast
                                        ? Colors.white
                                        : AppColors.onTertiaryFixedVariant)
                                  : lembrete.status == LembreteStatus.adiado
                                  ? (isHighContrast
                                        ? Colors.black
                                        : AppColors.onSecondaryFixedVariant)
                                  : Colors.white,
                              size: 36,
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              color: isHighContrast ? Colors.black : accentColor,
                              size: 36,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(barIcon, color: barFg, size: 20),
                  const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        barText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: barFg,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(Lembrete lembrete) {
    switch (lembrete.status) {
      case LembreteStatus.concluido:
      case LembreteStatus.concluidoComFoto:
      case LembreteStatus.confirmadoPeloCuidador:
        return 'Pronto!';
      case LembreteStatus.adiado:
        return 'Mais tarde';
      case LembreteStatus.perdido:
        return 'Não deu';
      case LembreteStatus.pendente:
        return lembrete.concluido ? 'Pronto!' : 'Falta fazer';
    }
  }

  Widget _buildTimeline(List<Lembrete> lembretes) {
    if (lembretes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 80,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum lembrete para hoje.\nAproveite o seu dia!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final sortedReminders = List<Lembrete>.from(lembretes)
      ..sort((a, b) {
        final aMin = a.horarioHour * 60 + a.horarioMinute;
        final bMin = b.horarioHour * 60 + b.horarioMinute;
        return aMin.compareTo(bMin);
      });

    final filteredReminders = _rotinaDoDiaOnly
        ? sortedReminders.where((l) => !l.concluido).toList()
        : sortedReminders;

    final sections = [
      _PeriodSection(
        title: 'MADRUGADA',
        subtitle: '00:00 - 05:59',
        icon: Icons.nightlight_round,
        color: PeriodHelper.getPeriodColor(2),
        reminders: filteredReminders
            .where((l) => l.horarioHour >= 0 && l.horarioHour < 6)
            .toList(),
      ),
      _PeriodSection(
        title: 'MANHÃ',
        subtitle: '06:00 - 11:59',
        icon: Icons.wb_sunny,
        color: PeriodHelper.getPeriodColor(8),
        reminders: filteredReminders
            .where((l) => l.horarioHour >= 6 && l.horarioHour < 12)
            .toList(),
      ),
      _PeriodSection(
        title: 'TARDE',
        subtitle: '12:00 - 17:59',
        icon: Icons.wb_twilight,
        color: PeriodHelper.getPeriodColor(14),
        reminders: filteredReminders
            .where((l) => l.horarioHour >= 12 && l.horarioHour < 18)
            .toList(),
      ),
      _PeriodSection(
        title: 'NOITE',
        subtitle: '18:00 - 23:59',
        icon: Icons.bedtime,
        color: PeriodHelper.getPeriodColor(20),
        reminders: filteredReminders
            .where((l) => l.horarioHour >= 18 && l.horarioHour < 24)
            .toList(),
      ),
    ];

    return Column(
      children: sections
          .map((sec) => _buildRoutineSection(sec, sortedReminders))
          .toList(),
    );
  }

  Widget _buildRoutineSection(
    _PeriodSection section,
    List<Lembrete> allSorted,
  ) {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    final total = section.reminders.length;
    final done = section.reminders.where((l) => l.concluido).length;

    final totalOriginal = allSorted.where((l) {
      if (section.title == 'MADRUGADA') {
        return l.horarioHour >= 0 && l.horarioHour < 6;
      }
      if (section.title == 'MANHÃ') {
        return l.horarioHour >= 6 && l.horarioHour < 12;
      }
      if (section.title == 'TARDE') {
        return l.horarioHour >= 12 && l.horarioHour < 18;
      }
      return l.horarioHour >= 18 && l.horarioHour < 24;
    }).length;

    final completedCount = totalOriginal - total;
    final completedText = completedCount == 1 ? 'concluído' : 'concluídos';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighContrast ? Colors.black : AppColors.outlineVariant,
          width: isHighContrast ? 3.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? Colors.black
                  : section.color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: isHighContrast
                  ? const Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isHighContrast ? Colors.white : section.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    section.icon,
                    color: isHighContrast ? Colors.black : Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isHighContrast ? Colors.white : section.color,
                        ),
                      ),
                      Text(
                        section.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isHighContrast
                              ? Colors.white70
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? Colors.black
                        : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isHighContrast
                          ? Colors.white
                          : section.color.withValues(alpha: 0.3),
                      width: isHighContrast ? 2.0 : 1.0,
                    ),
                  ),
                  child: Text(
                    _rotinaDoDiaOnly
                        ? '$completedCount $completedText'
                        : '$done/$total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isHighContrast ? Colors.white : section.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (section.reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    totalOriginal > 0
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: totalOriginal > 0
                        ? (isHighContrast ? Colors.black : Colors.green)
                        : (isHighContrast ? Colors.black54 : AppColors.outline),
                    size: totalOriginal > 0 ? 28 : 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      totalOriginal > 0
                          ? 'Tudo concluído neste período! 🎉'
                          : 'Nenhum lembrete neste período',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: totalOriginal > 0
                            ? (isHighContrast
                                  ? Colors.black
                                  : Colors.green[800])
                            : (isHighContrast
                                  ? Colors.black54
                                  : AppColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.reminders.length,
              itemBuilder: (context, index) {
                final lembrete = section.reminders[index];
                final isFirst = index == 0;
                final isLast = index == section.reminders.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 100,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              section.icon,
                              color: isHighContrast
                                  ? Colors.black
                                  : section.color,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? Colors.black
                                    : section.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: isHighContrast
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Text(
                                lembrete.horarioFormatado,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isHighContrast
                                      ? Colors.white
                                      : section.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: 4,
                                color: isFirst
                                    ? Colors.transparent
                                    : (isHighContrast
                                          ? Colors.black
                                          : section.color.withValues(
                                              alpha: 0.35,
                                            )),
                              ),
                            ),
                            _buildNode(lembrete),
                            Expanded(
                              child: Container(
                                width: 4,
                                color: isLast
                                    ? Colors.transparent
                                    : (isHighContrast
                                          ? Colors.black
                                          : section.color.withValues(
                                              alpha: 0.35,
                                            )),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12, right: 12),
                          child: _buildReminderCard(lembrete),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = AppColors.background;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          floatingActionButton: _buildSOSFAB(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: SafeArea(
            child: Column(
              children: [
                const VolumeWarningBanner(),
                _buildTopBar(),
                const DeviceBarrierBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        if (_isConnected) ...[
                          _buildConnectedBadge(),
                          const SizedBox(height: 12),
                        ],
                        if (_showWelfareCheckin) ...[
                          _buildWelfareCheckinCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildVoiceButton(),
                        const SizedBox(height: 24),
                        Text(
                          'Aperte para falar comigo',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                        _buildNextReminderBanner(),
                        const SizedBox(height: 24),
                        _buildRotinaToggle(),
                        const SizedBox(height: 24),
                        _buildTimeline(_lembretes),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
        if (_confettiController != null && _confettiController!.value < 1.0)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(
                particles: _confetti,
                animationValue: _confettiController!.value,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lembrete Amigo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                MeExplicaButton(
                  textoExplicacao:
                      'Olá! Esta é a tela do seu dia. Aqui você vê as tarefas de tomar remédios, beber água, comer ou fazer exercícios. Para falar com o ajudante Alex, aperte o grande círculo azul no meio da tela e fale o que precisa.',
                  onTapped: _stopAllAudioAndTts,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (_isProcessingAction) return;
              setState(() => _isProcessingAction = true);
              try {
                _stopAllAudioAndTts();
                await Navigator.pushNamed(context, '/elderly-profile');
                await _updateConnectionStatus();
                _loadProfilePhoto();
                _checkWelfareStatus();
              } finally {
                if (mounted) {
                  setState(() => _isProcessingAction = false);
                }
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    return GestureDetector(
      onTap: _abrirGravacao,
      child: Container(
        width: 176,
        height: 176,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighContrast ? Colors.yellow : AppColors.secondaryContainer,
          border: Border.all(
            color: isHighContrast ? Colors.black : Colors.white,
            width: 8,
          ),
          boxShadow: isHighContrast
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic,
              size: 64,
              color: isHighContrast
                  ? Colors.black
                  : AppColors.onSecondaryContainer,
            ),
            Text(
              'Falar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isHighContrast
                    ? Colors.black
                    : AppColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBadge() {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isHighContrast
            ? Colors.white
            : (_isOnline
                  ? AppColors.tertiaryFixedDim.withValues(alpha: 0.2)
                  : AppColors.errorContainer.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isHighContrast
              ? Colors.black
              : (_isOnline ? Colors.transparent : AppColors.error),
          width: isHighContrast ? 2.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 20,
            color: isHighContrast
                ? Colors.black
                : (_isOnline
                      ? AppColors.onTertiaryFixedVariant
                      : AppColors.error),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Conectado' : 'Sem Internet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isHighContrast
                  ? Colors.black
                  : (_isOnline
                        ? AppColors.onTertiaryFixedVariant
                        : AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextReminderBanner() {
    final isHighContrast =
        Theme.of(context).colorScheme.primary == Colors.black;
    final lembrete = _ultimoLembrete;
    if (lembrete == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHighContrast
                ? Colors.black
                : AppColors.outlineVariant.withValues(alpha: 0.5),
            width: isHighContrast ? 4.0 : 2.5,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: AppColors.onSurfaceVariant,
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum lembrete para hoje',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Color categoryColor = isHighContrast ? Colors.black : AppColors.primary;
    IconData categoryIcon = Icons.notifications;

    if (!isHighContrast) {
      switch (lembrete.categoria) {
        case 'medicacao':
          categoryColor = AppColors.medicationsColor;
          categoryIcon = Icons.medication;
          break;
        case 'refeicoes':
          categoryColor = AppColors.mealsColor;
          categoryIcon = Icons.restaurant;
          break;
        case 'exercicio':
          categoryColor = AppColors.tertiaryContainer;
          categoryIcon = Icons.directions_walk;
          break;
        case 'hidratacao':
          categoryColor = AppColors.voiceFeedbackBlue;
          categoryIcon = Icons.water_drop;
          break;
        default:
          categoryColor = AppColors.customColor;
          categoryIcon = Icons.notifications;
      }
    } else {
      switch (lembrete.categoria) {
        case 'medicacao':
          categoryIcon = Icons.medication;
          break;
        case 'refeicoes':
          categoryIcon = Icons.restaurant;
          break;
        case 'exercicio':
          categoryIcon = Icons.directions_walk;
          break;
        case 'hidratacao':
          categoryIcon = Icons.water_drop;
          break;
        default:
          categoryIcon = Icons.notifications;
      }
    }

    final remainingTime = _tempoRestante(lembrete);

    if (_pulseAnimation == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHighContrast
                ? Colors.black
                : categoryColor.withValues(alpha: 0.5),
            width: isHighContrast ? 4.0 : 3.5,
          ),
          boxShadow: isHighContrast
              ? null
              : [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 16, color: categoryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? Colors.black
                                    : categoryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                categoryIcon,
                                color: isHighContrast
                                    ? Colors.white
                                    : categoryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SUA PRÓXIMA TAREFA',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                      color: isHighContrast
                                          ? Colors.black
                                          : categoryColor,
                                    ),
                                  ),
                                  if (remainingTime.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      remainingTime.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isHighContrast
                                            ? Colors.black
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${lembrete.titulo} — ${lembrete.horarioFormatado}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isHighContrast
                                ? Colors.black
                                : AppColors.primary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _ouvirExplicacaoLembrete(lembrete),
                                icon: const Icon(Icons.volume_up, size: 24),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'OUVIR EXPLICAÇÃO',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHighContrast
                                      ? Colors.yellow
                                      : AppColors.secondaryContainer,
                                  foregroundColor: isHighContrast
                                      ? Colors.black
                                      : AppColors.onSecondaryContainer,
                                  elevation: 0,
                                  side: isHighContrast
                                      ? const BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        )
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            if (lembrete.audioPath != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _playAudio(lembrete.audioPath!),
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.stop
                                        : Icons.play_arrow,
                                    size: 24,
                                  ),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'OUVIR VOZ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isHighContrast
                                        ? Colors.white
                                        : AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                    foregroundColor: isHighContrast
                                        ? Colors.black
                                        : AppColors.primary,
                                    elevation: 0,
                                    side: isHighContrast
                                        ? const BorderSide(
                                            color: Colors.black,
                                            width: 2.5,
                                          )
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, child) {
        final scale = _pulseAnimation!.value;
        final glowWidth = (scale - 1.0) * 120; // 0 to 6 pixels
        final alphaFactor = 0.5 + (scale - 1.0) * 4.0; // 0.5 to 0.7

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isHighContrast ? Colors.white : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHighContrast
                  ? Colors.black
                  : categoryColor.withValues(alpha: alphaFactor),
              width: isHighContrast ? 4.0 : 3.5,
            ),
            boxShadow: isHighContrast
                ? null
                : [
                    BoxShadow(
                      color: categoryColor.withValues(
                        alpha: 0.15 + (scale - 1.0) * 3.0,
                      ),
                      blurRadius: 12 + glowWidth,
                      spreadRadius: 1 + glowWidth * 0.5,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 16, color: categoryColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isHighContrast
                                      ? Colors.black
                                      : categoryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  categoryIcon,
                                  color: isHighContrast
                                      ? Colors.white
                                      : categoryColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SUA PRÓXIMA TAREFA',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                        color: isHighContrast
                                            ? Colors.black
                                            : categoryColor,
                                      ),
                                    ),
                                    if (remainingTime.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        remainingTime.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: isHighContrast
                                              ? Colors.black
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${lembrete.titulo} — ${lembrete.horarioFormatado}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isHighContrast
                                  ? Colors.black
                                  : AppColors.primary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _ouvirExplicacaoLembrete(lembrete),
                                  icon: const Icon(Icons.volume_up, size: 24),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'OUVIR EXPLICAÇÃO',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isHighContrast
                                        ? Colors.yellow
                                        : AppColors.secondaryContainer,
                                    foregroundColor: isHighContrast
                                        ? Colors.black
                                        : AppColors.onSecondaryContainer,
                                    elevation: 0,
                                    side: isHighContrast
                                        ? const BorderSide(
                                            color: Colors.black,
                                            width: 2,
                                          )
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              if (lembrete.audioPath != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _playAudio(lembrete.audioPath!),
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                      size: 24,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'OUVIR VOZ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isHighContrast
                                          ? Colors.white
                                          : AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                      foregroundColor: isHighContrast
                                          ? Colors.black
                                          : AppColors.primary,
                                      elevation: 0,
                                      side: isHighContrast
                                          ? const BorderSide(
                                              color: Colors.black,
                                              width: 2.5,
                                            )
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.home, 'Início', true, null),
              _bottomNavItem(Icons.list_alt, 'Lembretes', false, () async {
                if (_isProcessingAction) return;
                setState(() => _isProcessingAction = true);
                try {
                  _stopAllAudioAndTts();
                  await Navigator.pushNamed(context, '/all-reminders');
                } finally {
                  if (mounted) {
                    setState(() => _isProcessingAction = false);
                  }
                }
              }),
              _bottomNavItem(Icons.help_center, 'Ajuda', false, () async {
                if (_isProcessingAction) return;
                setState(() => _isProcessingAction = true);
                try {
                  _stopAllAudioAndTts();
                  await Navigator.pushNamed(context, '/elderly-help');
                } finally {
                  if (mounted) {
                    setState(() => _isProcessingAction = false);
                  }
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback? onTap,
  ) {
    final itemColor = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: itemColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _PeriodSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Lembrete> reminders;

  const _PeriodSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.reminders,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double animationValue;

  _ConfettiPainter({required this.particles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue >= 1.0) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final double screenX = (p.x / 400) * size.width;
      if (p.y > size.height) continue;

      canvas.save();
      canvas.translate(screenX, p.y);
      canvas.rotate(p.rotation);

      paint.color = p.color;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
