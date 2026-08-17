import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/session_role_service.dart';
import '../utils/audio_path_helper.dart';
import 'audio_manager.dart';
import 'alex_avatar.dart';

class AudioPlayerCard extends StatefulWidget {
  final Color? _accentColor;
  Color get accentColor => _accentColor ?? AppColors.primary;
  final String? title;
  final String subtitle;
  final String? audioPath;
  final List<String>? textsToSpeak;
  final String? nextReminderText;
  final bool isChatDesign;
  final Duration? defaultDuration;

  const AudioPlayerCard({
    super.key,
    Color? accentColor,
    this.title,
    this.subtitle = 'Ouça todos os lembretes do dia',
    this.audioPath,
    this.textsToSpeak,
    this.nextReminderText,
    this.isChatDesign = false,
    this.defaultDuration,
  }) : _accentColor = accentColor;

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard>
    with TickerProviderStateMixin {
  final int audioId = AudioManager.generateId();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  bool _isPlaying = false;
  late AnimationController _waveController;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  int _currentIndex = 0;
  String? _currentSpeakingText;
  int _speedIndex = 1; // 0: 0.8x, 1: 1.0x, 2: 1.2x
  static const List<double> _speeds = [0.8, 1.0, 1.2];
  bool _isSingleNextPlay = false;
  bool _isSkippingOrRepeating = false;
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultDuration != null) {
      _duration = widget.defaultDuration!;
    }
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) _onAudioComplete();
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    AudioManager.activeIdNotifier.addListener(_onActiveIdChanged);

    // Preload source to fetch and display audio duration immediately on screen
    if (_hasAudio) {
      _audioPlayer.setSource(audioSourceForPath(widget.audioPath!)).catchError((
        e,
      ) {
        debugPrint('Erro ao definir fonte de áudio inicial no init: $e');
      });
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      setState(() {
        _position = Duration.zero;
        _duration = widget.defaultDuration ?? Duration.zero;
      });
      if (_hasAudio) {
        _audioPlayer
            .setSource(audioSourceForPath(widget.audioPath!))
            .catchError((e) {
              debugPrint(
                'Erro ao atualizar fonte de áudio no didUpdateWidget: $e',
              );
            });
      }
    } else if (oldWidget.defaultDuration != widget.defaultDuration) {
      setState(() {
        _duration = widget.defaultDuration ?? Duration.zero;
      });
    }
  }

  void _onAudioComplete() {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isSingleNextPlay = false;
      _currentSpeakingText = null;
      _position = Duration.zero;
      _waveController.stop();
      _waveController.reset();
    });
    AudioManager.stopPlay(audioId);
  }

  void _onActiveIdChanged() {
    if (_isPlaying && AudioManager.activeIdNotifier.value != audioId) {
      _stopRequested = true;
      _audioPlayer.stop();
      TTSService.instance.parar(caller: this);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isSingleNextPlay = false;
          _currentSpeakingText = null;
          _position = Duration.zero;
          _waveController.stop();
          _waveController.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    AudioManager.activeIdNotifier.removeListener(_onActiveIdChanged);
    AudioManager.stopPlay(audioId);
    if (_isPlaying) {
      TTSService.instance.parar(caller: this);
    }
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  bool get _hasTts =>
      (widget.textsToSpeak != null && widget.textsToSpeak!.isNotEmpty) ||
      (widget.nextReminderText != null && widget.nextReminderText!.isNotEmpty);
  bool get _hasAudio =>
      widget.audioPath != null && widget.audioPath!.isNotEmpty;
  bool get _canPlay => _hasTts || _hasAudio;

  void _togglePlay() {
    if (!_canPlay) return;

    if (_isPlaying) {
      _stopRequested = true;
      _audioPlayer.stop();
      TTSService.instance.parar(caller: this);
      _onAudioComplete();
    } else {
      if (!AudioManager.requestPlay(audioId)) return;
      _stopRequested = false;
      _isSingleNextPlay = false;
      _currentIndex = 0;
      setState(() {
        _isPlaying = true;
        _waveController.repeat(reverse: true);
      });

      if (_hasTts && widget.textsToSpeak != null && widget.textsToSpeak!.isNotEmpty) {
        _speakTexts();
      } else {
        _playAudio();
      }
    }
  }

  Future<void> _speakTexts() async {
    final texts = widget.textsToSpeak;
    if (texts == null || texts.isEmpty) {
      _onAudioComplete();
      return;
    }

    _stopRequested = false;
    _currentIndex = 0;

    while (_currentIndex < texts.length && mounted && !_stopRequested && _isPlaying) {
      final currentText = texts[_currentIndex];
      setState(() {
        _currentSpeakingText = currentText;
      });

      _isSkippingOrRepeating = false;

      try {
        await TTSService.instance.falar(currentText, caller: this);
      } catch (e) {
        debugPrint('Erro ao falar texto: $e');
      }

      if (_stopRequested || !_isPlaying || !mounted) {
        break;
      }

      if (_isSkippingOrRepeating) {
        continue;
      }

      _currentIndex++;
      if (_currentIndex < texts.length && _isPlaying && !_stopRequested) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (mounted) {
      _onAudioComplete();
    }
  }

  void _nextItem() {
    HapticFeedback.lightImpact();
    if (widget.textsToSpeak == null) return;
    if (_currentIndex < widget.textsToSpeak!.length - 1) {
      _isSkippingOrRepeating = true;
      _currentIndex++;
      TTSService.instance.parar(caller: this);
    }
  }

  void _repeatItem() {
    HapticFeedback.lightImpact();
    _isSkippingOrRepeating = true;
    TTSService.instance.parar(caller: this);
  }

  void _toggleSpeed() async {
    HapticFeedback.lightImpact();
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
    });
    final currentSpeed = _speeds[_speedIndex];
    final speechRate = currentSpeed * 0.50; // 0.8x -> 0.40, 1.0x -> 0.50, 1.2x -> 0.60
    await TTSService.instance.setSpeechRate(speechRate);
  }

  void _playSingleNext() async {
    if (widget.nextReminderText == null || widget.nextReminderText!.isEmpty) return;
    if (!AudioManager.requestPlay(audioId)) return;

    _stopRequested = false;
    setState(() {
      _isPlaying = true;
      _isSingleNextPlay = true;
      _currentSpeakingText = widget.nextReminderText;
      _waveController.repeat(reverse: true);
    });

    try {
      await TTSService.instance.falar(widget.nextReminderText!, caller: this);
    } catch (e) {
      debugPrint('Erro ao falar próximo lembrete: $e');
    }

    if (mounted) _onAudioComplete();
  }

  Future<void> _playAudio() async {
    if (!await audioPathExists(widget.audioPath!)) {
      AudioManager.stopPlay(audioId);
      debugPrint('Arquivo de áudio não encontrado: ${widget.audioPath}');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _waveController.stop();
          _waveController.reset();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não encontrei o som. Grave de novo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    try {
      await _audioPlayer.play(
        audioSourceForPath(widget.audioPath!),
        volume: 1.0,
      );
    } catch (e) {
      AudioManager.stopPlay(audioId);
      debugPrint('Erro ao reproduzir áudio: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _waveController.stop();
          _waveController.reset();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não consegui tocar o som. Tente de novo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isChatDesign) {
      final isElderly = SessionRoleService.isElderly;
      final double playIconSize = isElderly ? 52.0 : 38.0;
      final double micIconSize = isElderly ? 28.0 : 22.0;
      final double trackHeight = isElderly ? 6.0 : 3.0;
      final double thumbRadius = isElderly ? 9.0 : 6.0;
      final double overlayRadius = isElderly ? 18.0 : 14.0;
      final double fontSize = isElderly ? 21.0 : 16.0;
      final double durationFontSize = isElderly ? 14.0 : 12.0;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isElderly ? 8.0 : 4.0,
          vertical: isElderly ? 10.0 : 6.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.35,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: widget.accentColor,
                    size: playIconSize,
                  ),
                  onPressed: _canPlay ? _togglePlay : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: trackHeight,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: thumbRadius,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: overlayRadius,
                          ),
                          activeTrackColor: widget.accentColor,
                          inactiveTrackColor: widget.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          thumbColor: widget.accentColor,
                          overlayColor: widget.accentColor.withValues(
                            alpha: 0.1,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Slider(
                          min: 0.0,
                          max: _duration.inMilliseconds.toDouble() > 0.0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                          value: _position.inMilliseconds.toDouble().clamp(
                            0.0,
                            _duration.inMilliseconds.toDouble() > 0.0
                                ? _duration.inMilliseconds.toDouble()
                                : 1.0,
                          ),
                          onChanged: (value) async {
                            final pos = Duration(milliseconds: value.toInt());
                            await _audioPlayer.seek(pos);
                          },
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _isPlaying
                              ? _formatDuration(_position)
                              : _formatDuration(_duration),
                          style: TextStyle(
                            fontSize: durationFontSize,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.mic, color: widget.accentColor, size: micIconSize),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(
          color: _isPlaying
              ? widget.accentColor
              : AppColors.outlineVariant,
          width: _isPlaying ? 2.5 : 1.5,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? widget.accentColor
                        : widget.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.volume_up : Icons.headphones,
                    color: _isPlaying ? Colors.white : widget.accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title ?? 'ESCUTE OS LEMBRETES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botão de Velocidade da Voz (0.8x / 1.0x / 1.2x)
                if (_hasTts)
                  InkWell(
                    onTap: _toggleSpeed,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _speedIndex != 1
                            ? AppColors.primaryContainer.withValues(alpha: 0.5)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _speedIndex != 1
                              ? widget.accentColor
                              : AppColors.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speed,
                            size: 16,
                            color: _speedIndex != 1
                                ? widget.accentColor
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_speeds[_speedIndex]}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _speedIndex != 1
                                  ? widget.accentColor
                                  : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // SE ESTIVER REPRODUZINDO
            if (_isPlaying) ...[
              // Barra de Progresso / Contagem de Lembretes
              if (_hasTts &&
                  widget.textsToSpeak != null &&
                  widget.textsToSpeak!.length > 1 &&
                  !_isSingleNextPlay) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currentIndex == 0
                          ? 'Apresentando os lembretes...'
                          : 'Lembrete $_currentIndex de ${widget.textsToSpeak!.length - 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                    Text(
                      '${((_currentIndex + 1) / widget.textsToSpeak!.length * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.textsToSpeak!.length,
                    backgroundColor: AppColors.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.accentColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Balão de Fala da Alex com o texto atual
              if (_currentSpeakingText != null &&
                  _currentSpeakingText!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const AlexAvatar(size: 38, animate: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentSpeakingText!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              _buildWaveform(),
              const SizedBox(height: 14),

              // Controles de Reprodução Ativa (Repetir / Parar / Próximo)
              Row(
                children: [
                  if (_hasTts &&
                      widget.textsToSpeak != null &&
                      widget.textsToSpeak!.length > 1 &&
                      !_isSingleNextPlay) ...[
                    // Botão Repetir
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _repeatItem,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onSurface,
                            side: BorderSide(
                              color: AppColors.outlineVariant,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.replay, size: 18),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Repetir',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Botão Parar Leitura
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _togglePlay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.onError,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.stop_circle, size: 22),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Parar leitura',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_hasTts &&
                      widget.textsToSpeak != null &&
                      widget.textsToSpeak!.length > 1 &&
                      !_isSingleNextPlay) ...[
                    const SizedBox(width: 8),
                    // Botão Próximo
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              _currentIndex < widget.textsToSpeak!.length - 1
                                  ? _nextItem
                                  : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.accentColor,
                            side: BorderSide(
                              color: widget.accentColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.skip_next,
                                size: 20,
                                color: widget.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Próximo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: widget.accentColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              // SE NÃO ESTIVER REPRODUZINDO (ESTADO INICIAL)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Botão Principal: Ouvir Todos
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _canPlay ? _togglePlay : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 28),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _hasAudio
                                    ? 'Ouvir mensagem'
                                    : (widget.textsToSpeak != null &&
                                            widget.textsToSpeak!.length > 1
                                        ? 'Ouvir todos (${widget.textsToSpeak!.length - 1})'
                                        : 'Ouvir lembretes'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Atalho Rápido: Ouvir o Próximo (se houver)
                  if (widget.nextReminderText != null &&
                      widget.nextReminderText!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _playSingleNext,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLow,
                            foregroundColor: widget.accentColor,
                            side: BorderSide(
                              color: widget.accentColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time_filled,
                                size: 18,
                                color: widget.accentColor,
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'O Próximo',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    final barCount = 40;
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return SizedBox(
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final seed = (i * 0.7 + i % 3 * 1.3);
              final baseHeight = 0.15 + (sin(seed) * 0.5 + 0.5) * 0.7;
              final animOffset =
                  sin(_waveController.value * pi * 2 + seed) * 0.3;
              final heightFactor = (baseHeight + animOffset).clamp(0.1, 1.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: 36 * heightFactor,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: 0.4 + heightFactor * 0.6,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
