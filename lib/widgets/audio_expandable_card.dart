import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../utils/audio_path_helper.dart';
import 'audio_manager.dart';
import 'alex_avatar.dart';

class AudioExpandableCard extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    VoidCallback onPlay,
    bool isPlaying,
  )
  cardBuilder;
  final Color accentColor;
  final String? textToSpeak;
  final String? audioPath;
  final Color? borderColor;

  const AudioExpandableCard({
    super.key,
    required this.cardBuilder,
    this.accentColor = AppColors.primary,
    this.textToSpeak,
    this.audioPath,
    this.borderColor,
  });

  @override
  State<AudioExpandableCard> createState() => _AudioExpandableCardState();
}

class _AudioExpandableCardState extends State<AudioExpandableCard>
    with TickerProviderStateMixin {
  final int audioId = AudioManager.generateId();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) _stopAll();
    });
    AudioManager.activeIdNotifier.addListener(_onActiveIdChanged);
    TTSService.instance.speakingNotifier.addListener(_onTtsStateChanged);
  }

  void _onTtsStateChanged() {
    if (_isPlaying &&
        !TTSService.instance.isSpeaking &&
        widget.audioPath == null) {
      _stopAll();
    }
  }

  void _onActiveIdChanged() {
    if (_isPlaying && AudioManager.activeIdNotifier.value != audioId) {
      _audioPlayer.stop();
      TTSService.instance.parar();
      _stopAll();
    }
  }

  void _stopAll() {
    setState(() {
      _isPlaying = false;
      _waveController.stop();
      _waveController.reset();
    });
    AudioManager.stopPlay(audioId);
  }

  @override
  void dispose() {
    AudioManager.activeIdNotifier.removeListener(_onActiveIdChanged);
    TTSService.instance.speakingNotifier.removeListener(_onTtsStateChanged);
    AudioManager.stopPlay(audioId);
    if (_isPlaying) {
      _audioPlayer.stop();
      TTSService.instance.parar();
    }
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  bool get _hasAudio =>
      widget.audioPath != null && widget.audioPath!.isNotEmpty;
  bool get _hasTts =>
      widget.textToSpeak != null && widget.textToSpeak!.isNotEmpty;
  bool get _canPlay => _hasAudio || _hasTts;

  void _togglePlay() {
    if (!_canPlay) return;

    if (_isPlaying) {
      _audioPlayer.stop();
      TTSService.instance.parar();
      _stopAll();
    } else {
      if (!AudioManager.requestPlay(audioId)) return;
      setState(() {
        _isPlaying = true;
        _waveController.repeat(reverse: true);
      });
      if (_hasAudio) {
        _playAudio();
      } else {
        _speak();
      }
    }
  }

  Future<void> _playAudio() async {
    if (!await audioPathExists(widget.audioPath!)) {
      _stopAll();
      debugPrint('Arquivo de áudio não encontrado: ${widget.audioPath}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Áudio não encontrado. Grave o lembrete novamente.',
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
      _stopAll();
      debugPrint('Erro ao reproduzir áudio do familiar: $e');
    }
  }

  Future<void> _speak() async {
    try {
      await TTSService.instance.falar(widget.textToSpeak!);
    } catch (e) {
      debugPrint('Erro ao falar: $e');
    }
    if (mounted) _stopAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(
          color: widget.borderColor ?? AppColors.outlineVariant,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          widget.cardBuilder(context, _togglePlay, _isPlaying),
          if (_isPlaying) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return SizedBox(
                    height: 32,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(24, (i) {
                        final seed = (i * 0.7 + i % 3 * 1.3);
                        final baseHeight = 0.15 + (sin(seed) * 0.5 + 0.5) * 0.7;
                        final animOffset =
                            sin(_waveController.value * pi * 2 + seed) * 0.3;
                        final heightFactor = (baseHeight + animOffset).clamp(
                          0.1,
                          1.0,
                        );
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: 32 * heightFactor,
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
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: AlexAvatar(size: 60, animate: true),
            ),
          ],
        ],
      ),
    );
  }
}
