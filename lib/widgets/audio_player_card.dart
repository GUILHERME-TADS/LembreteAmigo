import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import 'audio_manager.dart';
import 'alex_avatar.dart';

class AudioPlayerCard extends StatefulWidget {
  final Color accentColor;
  final String subtitle;
  final String? audioPath;
  final List<String>? textsToSpeak;

  const AudioPlayerCard({
    super.key,
    this.accentColor = AppColors.primary,
    this.subtitle = 'Ouça todos os lembretes do dia',
    this.audioPath,
    this.textsToSpeak,
  });

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard>
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
      if (mounted) _onAudioComplete();
    });
    AudioManager.activeIdNotifier.addListener(_onActiveIdChanged);
  }

  void _onAudioComplete() {
    setState(() {
      _isPlaying = false;
      _waveController.stop();
      _waveController.reset();
    });
    AudioManager.stopPlay(audioId);
  }

  void _onActiveIdChanged() {
    if (_isPlaying && AudioManager.activeIdNotifier.value != audioId) {
      _audioPlayer.stop();
      TTSService.instance.parar();
      setState(() {
        _isPlaying = false;
        _waveController.stop();
        _waveController.reset();
      });
    }
  }

  @override
  void dispose() {
    AudioManager.activeIdNotifier.removeListener(_onActiveIdChanged);
    AudioManager.stopPlay(audioId);
    if (_isPlaying) {
      TTSService.instance.parar();
    }
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  bool get _hasTts => widget.textsToSpeak != null && widget.textsToSpeak!.isNotEmpty;
  bool get _hasAudio => widget.audioPath != null;
  bool get _canPlay => _hasTts || _hasAudio;

  void _togglePlay() {
    if (!_canPlay) return;

    if (_isPlaying) {
      _audioPlayer.stop();
      TTSService.instance.parar();
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
    final file = File(widget.audioPath!);
    if (!await file.exists()) {
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
            content: const Text('Áudio não encontrado. Grave o lembrete novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    try {
      await _audioPlayer.play(
        DeviceFileSource(widget.audioPath!),
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
            content: Text('Erro ao reproduzir áudio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_fill,
                  color: _canPlay ? widget.accentColor : AppColors.outlineVariant,
                  size: 40,
                ),
              ],
            ),
            if (_isPlaying) ...[
              const SizedBox(height: 16),
              _buildWaveform(),
              const SizedBox(height: 12),
              const Center(
                child: AlexAvatar(size: 60, animate: true),
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
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final seed = (i * 0.7 + i % 3 * 1.3);
              final baseHeight = 0.15 + (sin(seed) * 0.5 + 0.5) * 0.7;
              final animOffset = sin(_waveController.value * pi * 2 + seed) * 0.3;
              final heightFactor = (baseHeight + animOffset).clamp(0.1, 1.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: 40 * heightFactor,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.4 + heightFactor * 0.6),
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
