import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/period_helper.dart';
import '../widgets/index.dart';

class ElderlyHomeScreen extends StatefulWidget {
  final bool showConnected;

  const ElderlyHomeScreen({super.key, this.showConnected = false});

  @override
  State<ElderlyHomeScreen> createState() => _ElderlyHomeScreenState();
}

class _ElderlyHomeScreenState extends State<ElderlyHomeScreen> with TickerProviderStateMixin {
  List<Lembrete> _lembretes = [];
  Lembrete? _ultimoLembrete;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _playingAudioPath;
  bool _isSpeaking = false;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  // Confetti Animations
  AnimationController? _confettiController;
  final List<_ConfettiParticle> _confetti = [];
  bool _allCompletedTriggered = false;

  bool get _isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());

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
          _lembretes = List.from(lembretes);
          _atualizarProximoLembrete();
          _checkVictoryConfetti();
        });
      }
    });
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
    TTSService.instance.speakingNotifier.addListener(_onTtsSpeakingChanged);
    _audioPlayer.onPlayerComplete.listen((_) {
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
        _lembretes = List.from(lembretes);
        _atualizarProximoLembrete();
        _checkVictoryConfetti();
      });
    }
  }

  void _checkVictoryConfetti() {
    final allDone = _lembretes.isNotEmpty && _lembretes.every((l) => l.concluido);
    if (allDone && !_allCompletedTriggered) {
      _allCompletedTriggered = true;
      _startConfetti();
    } else if (!allDone) {
      _allCompletedTriggered = false;
    }
  }

  void _startConfetti() {
    final random = math.Random();
    _confetti.clear();
    for (int i = 0; i < 80; i++) {
      _confetti.add(_ConfettiParticle(
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
          Colors.purpleAccent
        ][random.nextInt(7)],
        rotation: random.nextDouble() * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.1,
      ));
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

  void _onTtsSpeakingChanged() {
    if (mounted) {
      setState(() {
        _isSpeaking = TTSService.instance.isSpeaking;
      });
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _confettiController?.dispose();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    TTSService.instance.speakingNotifier.removeListener(_onTtsSpeakingChanged);
    TTSService.instance.parar(caller: this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
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
    setState(() => _isSpeaking = false);
  }

  Future<void> _abrirGravacao() async {
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
  }

  void _playAudio(String path) async {
    if (_isSpeaking) {
      await TTSService.instance.parar(caller: this);
      if (mounted) setState(() => _isSpeaking = false);
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
      await _audioPlayer.play(DeviceFileSource(path));
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

    if (_isSpeaking) {
      TTSService.instance.parar(caller: this);
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    final text = _descreverLembrete(l);
    await TTSService.instance.falar(text, caller: this);
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _toggleSpeak() {
    if (_ultimoLembrete == null) return;
    _speakReminder(_ultimoLembrete!);
  }

  String _descreverLembrete(Lembrete l) {
    final spokenTime = PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute);
    var desc = '${l.titulo} às $spokenTime.';
    
    if (l.categoria == 'medicacao' && l.medicamentoForma != null && l.medicamentoCor != null) {
      final formaLabel = l.medicamentoForma == 'capsula'
          ? 'cápsula'
          : l.medicamentoForma == 'comprimido'
              ? 'comprimido'
              : l.medicamentoForma == 'gotas'
                  ? 'gotas'
                  : 'pomada';
      final corLabel = l.medicamentoCor;
      desc += ' Tomar uma $formaLabel na cor $corLabel.';
    }
    return desc;
  }

  Widget _buildNode(Lembrete lembrete) {
    final bool isMed = lembrete.categoria == 'medicacao';
    Color bg;
    IconData? icon;
    Color iconColor = Colors.white;
    
    if (lembrete.concluido) {
      bg = AppColors.tertiaryFixedDim;
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
      innerWidget = Icon(
        icon,
        size: 32.0,
        color: iconColor,
      );
    }
    
    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: lembrete.concluido ? AppColors.onTertiaryFixedVariant : Colors.white,
          width: 3,
        ),
        boxShadow: const [
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
                decoration: const BoxDecoration(
                  color: Color(0xFF005312),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Lembrete lembrete) {
    final isNight = _isNightTime;
    final isMed = lembrete.categoria == 'medicacao';
    String subtitle = '';
    if (isMed && lembrete.medicamentoForma != null && lembrete.medicamentoCor != null) {
      final formaLabel = lembrete.medicamentoForma == 'capsula'
          ? 'Cápsula'
          : lembrete.medicamentoForma == 'comprimido'
              ? 'Comprimido'
              : lembrete.medicamentoForma == 'gotas'
                  ? 'Gotas'
                  : 'Pomada';
      subtitle = '$formaLabel ${lembrete.medicamentoCor}';
    } else {
      subtitle = lembrete.concluido ? 'Tudo certo!' : 'Falta fazer';
    }

    final cardBg = lembrete.concluido 
        ? (isNight ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9)) 
        : (isNight ? const Color(0xFF1E293B) : AppColors.surfaceContainerLowest);

    final titleColor = lembrete.concluido 
        ? (isNight ? Colors.greenAccent : AppColors.onTertiaryFixedVariant) 
        : (isNight ? Colors.white : AppColors.primary);

    return Card(
      elevation: 2,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: lembrete.concluido ? AppColors.tertiaryFixedDim : AppColors.outlineVariant,
          width: 2,
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
        child: Padding(
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
                        decoration: lembrete.concluido ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isNight ? Colors.white70 : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (lembrete.audioPath != null)
                IconButton(
                  icon: Icon(
                    _isPlaying && _playingAudioPath == lembrete.audioPath ? Icons.stop : Icons.play_arrow,
                    color: isNight ? Colors.white : AppColors.primary,
                    size: 32,
                  ),
                  onPressed: () => _playAudio(lembrete.audioPath!),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  if (isMed && !lembrete.concluido) {
                    Navigator.pushNamed(context, '/take-photo-confirmation', arguments: lembrete.id);
                  } else {
                    await LembreteService.instance.alternarConclusao(lembrete.id);
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: lembrete.concluido ? AppColors.tertiaryFixedDim : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lembrete.concluido ? AppColors.onTertiaryFixedVariant : AppColors.outline,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    lembrete.concluido ? Icons.check : Icons.circle_outlined,
                    color: lembrete.concluido ? AppColors.onTertiaryFixedVariant : AppColors.outline,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<Lembrete> lembretes) {
    if (lembretes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                _stopAllAudioAndTts();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AlexAssistantSheet(lembretes: _lembretes),
                );
              },
              child: const AlexAvatar(size: 120),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum lembrete para hoje.\nAperte no meu rosto ou no botão grande para falar comigo!',
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

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedReminders.length,
      itemBuilder: (context, index) {
        final lembrete = sortedReminders[index];
        final isFirst = index == 0;
        final isLast = index == sortedReminders.length - 1;

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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isNightTime ? const Color(0xFF1E293B) : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lembrete.horarioFormatado,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _isNightTime ? Colors.amberAccent : AppColors.primary,
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
                    Container(
                      width: 4,
                      height: 16,
                      color: isFirst ? Colors.transparent : AppColors.outlineVariant,
                    ),
                    _buildNode(lembrete),
                    Expanded(
                      child: Container(
                        width: 4,
                        color: isLast ? Colors.transparent : AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildReminderCard(lembrete),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isNight = _isNightTime;
    final bgColor = isNight ? const Color(0xFF0F172A) : AppColors.background;
    final primaryTextColor = isNight ? const Color(0xFFFCD34D) : AppColors.primary;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const VolumeWarningBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        if (widget.showConnected) ...[
                          const SizedBox(height: 12),
                          _buildConnectedBadge(),
                        ],
                        const SizedBox(height: 24),
                        _buildVoiceButton(),
                        const SizedBox(height: 24),
                        Text(
                          'Aperte para falar comigo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildNextReminderBanner(),
                        const SizedBox(height: 24),
                        _buildTimeline(_lembretes),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
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
    final isNight = _isNightTime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF1E293B) : AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: isNight ? Colors.white : AppColors.primary, size: 32),
            onPressed: () {
              _stopAllAudioAndTts();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          const Spacer(),
          Text(
            'Lembrete Amigo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isNight ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              _stopAllAudioAndTts();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AlexAssistantSheet(lembretes: _lembretes),
              );
            },
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              _stopAllAudioAndTts();
              Navigator.pushNamed(context, '/elderly-profile');
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: isNight ? Colors.amberAccent : AppColors.primaryContainer, width: 2),
                ),
              ),
              child: Icon(Icons.person, color: isNight ? Colors.amberAccent : AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: _abrirGravacao,
      child: Container(
        width: 176,
        height: 176,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondaryContainer,
          border: Border.all(color: Colors.white, width: 8),
          boxShadow: const [
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
            const Icon(
              Icons.mic,
              size: 64,
              color: AppColors.onSecondaryContainer,
            ),
            Text(
              'Falar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline
            ? AppColors.tertiaryFixedDim.withValues(alpha: 0.2)
            : AppColors.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: _isOnline ? Colors.transparent : AppColors.error,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: _isOnline ? AppColors.onTertiaryFixedVariant : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Conectado' : 'Sem Internet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _isOnline ? AppColors.onTertiaryFixedVariant : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextReminderBanner() {
    final lembrete = _ultimoLembrete;
    Color categoryColor = AppColors.primary;
    IconData categoryIcon = Icons.notifications;

    if (lembrete != null) {
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
    }

    final isNight = _isNightTime;
    final bannerBg = isNight ? const Color(0xFF1E293B) : AppColors.surfaceContainerLowest;

    return GestureDetector(
      onTap: () {
        _stopAllAudioAndTts();
        Navigator.pushNamed(context, '/all-reminders');
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 12,
                  color: categoryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(categoryIcon, color: categoryColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'PRÓXIMO LEMBRETE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lembrete != null
                                    ? '${lembrete.titulo} — ${lembrete.horarioFormatado}'
                                    : 'Nenhum lembrete ainda',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isNight ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: lembrete != null
                              ? (lembrete.audioPath != null
                                  ? () => _playAudio(lembrete.audioPath!)
                                  : _toggleSpeak)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying || _isSpeaking
                                  ? Icons.stop
                                  : Icons.play_arrow,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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

  Widget _buildBottomNav() {
    final isNight = _isNightTime;
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF1E293B) : AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 2),
        ),
      ),
      child: Row(
        children: [
          _bottomNavItem(Icons.home, 'Início', true, null),
          _bottomNavItem(Icons.list_alt, 'Lembretes', false, () {
            _stopAllAudioAndTts();
            Navigator.pushNamed(context, '/all-reminders');
          }),
          _bottomNavItem(Icons.help_center, 'Ajuda', false, () {
            _stopAllAudioAndTts();
            Navigator.pushNamed(context, '/elderly-help');
          }),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool selected, VoidCallback? onTap) {
    final isNight = _isNightTime;
    final itemColor = selected 
        ? AppColors.onSecondaryContainer 
        : (isNight ? Colors.white70 : AppColors.onSurfaceVariant);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: itemColor),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
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
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
