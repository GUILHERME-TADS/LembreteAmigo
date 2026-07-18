import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/session_role_service.dart';
import '../utils/audio_path_helper.dart';
import 'audio_manager.dart';
import 'alex_avatar.dart';

class AudioPlayerCard extends StatefulWidget {
  final Color accentColor;
  final String subtitle;
  final String? audioPath;
  final List<String>? textsToSpeak;
  final bool isChatDesign;
  final Duration? defaultDuration;

  const AudioPlayerCard({
    super.key,
    this.accentColor = AppColors.primary,
    this.subtitle = 'Ouça todos os lembretes do dia',
    this.audioPath,
    this.textsToSpeak,
    this.isChatDesign = false,
    this.defaultDuration,
  });

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
      _audioPlayer.setSource(audioSourceForPath(widget.audioPath!)).catchError((e) {
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
        _audioPlayer.setSource(audioSourceForPath(widget.audioPath!)).catchError((e) {
          debugPrint('Erro ao atualizar fonte de áudio no didUpdateWidget: $e');
        });
      }
    } else if (oldWidget.defaultDuration != widget.defaultDuration) {
      setState(() {
        _duration = widget.defaultDuration ?? Duration.zero;
      });
    }
  }

  void _onAudioComplete() {
    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
      _waveController.stop();
      _waveController.reset();
    });
    AudioManager.stopPlay(audioId);
  }

  void _onActiveIdChanged() {
    if (_isPlaying && AudioManager.activeIdNotifier.value != audioId) {
      _audioPlayer.stop();
      TTSService.instance.parar(caller: this);
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _waveController.stop();
        _waveController.reset();
      });
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
      widget.textsToSpeak != null && widget.textsToSpeak!.isNotEmpty;
  bool get _hasAudio =>
      widget.audioPath != null && widget.audioPath!.isNotEmpty;
  bool get _canPlay => _hasTts || _hasAudio;

  void _togglePlay() {
    if (!_canPlay) return;

    if (_isPlaying) {
      _audioPlayer.stop();
      TTSService.instance.parar(caller: this);
      _onAudioComplete();
    } else {
      if (!AudioManager.requestPlay(audioId)) return;
      setState(() {
        _isPlaying = true;
        _waveController.repeat(reverse: true);
      });

      if (_hasTts) {
        _speakTexts();
      } else {
        _playAudio();
      }
    }
  }

  Future<void> _speakTexts() async {
    try {
      await TTSService.instance.falarLista(widget.textsToSpeak!, caller: this);
    } catch (e) {
      debugPrint('Erro ao falar: $e');
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
            content: const Text(
              'Não encontrei o som. Grave de novo.',
            ),
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
          const SnackBar(
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
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
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
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: overlayRadius),
                          activeTrackColor: widget.accentColor,
                          inactiveTrackColor: widget.accentColor.withValues(alpha: 0.2),
                          thumbColor: widget.accentColor,
                          overlayColor: widget.accentColor.withValues(alpha: 0.1),
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
                                  : 1.0),
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
                Icon(
                  Icons.mic,
                  color: widget.accentColor,
                  size: micIconSize,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _canPlay ? _togglePlay : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.05),
          border: Border.all(color: widget.accentColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _canPlay
                        ? widget.accentColor
                        : AppColors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.stop : Icons.volume_up,
                    color: _canPlay ? Colors.white : AppColors.onSurfaceVariant,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESCUTE OS LEMBRETES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_fill,
                  color: _canPlay
                      ? widget.accentColor
                      : AppColors.outlineVariant,
                  size: 40,
                ),
              ],
            ),
            if (_isPlaying) ...[
              const SizedBox(height: 16),
              _buildWaveform(),
              const SizedBox(height: 12),
              const Center(child: AlexAvatar(size: 60, animate: true)),
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
          height: 40,
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
                    height: 40 * heightFactor,
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
