import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/period_helper.dart';
import 'audio_manager.dart';

enum ReminderStatus { done, late, scheduled }

class ReminderWithAudio extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String time;
  final VoidCallback onTap;
  final ReminderStatus status;
  final Color accentColor;
  final String? audioPath;

  const ReminderWithAudio({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.time,
    required this.onTap,
    this.status = ReminderStatus.scheduled,
    this.accentColor = AppColors.primary,
    this.audioPath,
  });

  @override
  State<ReminderWithAudio> createState() => _ReminderWithAudioState();
}

class _ReminderWithAudioState extends State<ReminderWithAudio>
    with TickerProviderStateMixin {
  final int audioId = AudioManager.generateId();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isSpeaking = false;
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
    if (AudioManager.activeIdNotifier.value != audioId) {
      if (_isPlaying) {
        _audioPlayer.stop();
      }
      if (_isSpeaking) {
        TTSService.instance.parar();
      }
      if (_isPlaying || _isSpeaking) {
        setState(() {
          _isPlaying = false;
          _isSpeaking = false;
          _waveController.stop();
          _waveController.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    AudioManager.activeIdNotifier.removeListener(_onActiveIdChanged);
    AudioManager.stopPlay(audioId);
    TTSService.instance.parar();
    _waveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (widget.audioPath != null) {
      if (_isPlaying) {
        _audioPlayer.stop();
        _onAudioComplete();
      } else {
        if (_isSpeaking) {
          TTSService.instance.parar();
          setState(() => _isSpeaking = false);
        }
        if (!AudioManager.requestPlay(audioId)) return;
        _audioPlayer.setVolume(1.0);
        setState(() {
          _isPlaying = true;
          _waveController.repeat(reverse: true);
        });
        _playAudio();
      }
    } else {
      _toggleTTS();
    }
  }

  void _toggleTTS() async {
    if (_isSpeaking) {
      await TTSService.instance.parar();
      _waveController.stop();
      _waveController.reset();
      AudioManager.stopPlay(audioId);
      setState(() => _isSpeaking = false);
    } else {
      if (!AudioManager.requestPlay(audioId)) return;
      setState(() => _isSpeaking = true);
      _waveController.repeat(reverse: true);
      final spokenTime = PeriodHelper.getSpokenTimeFromStr(widget.time);
      final texto = '${widget.title} às $spokenTime';
      await TTSService.instance.falar(texto);
      _waveController.stop();
      _waveController.reset();
      AudioManager.stopPlay(audioId);
      if (mounted) setState(() => _isSpeaking = false);
    }
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(
          color: widget.status == ReminderStatus.done
              ? AppColors.tertiaryFixedDim
              : widget.status == ReminderStatus.late
                  ? AppColors.error
                  : widget.accentColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.status == ReminderStatus.done
                        ? AppColors.tertiaryFixedDim.withValues(alpha: 0.3)
                        : widget.status == ReminderStatus.late
                            ? AppColors.error.withValues(alpha: 0.15)
                            : widget.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.status == ReminderStatus.done
                        ? AppColors.onTertiaryFixedVariant
                        : widget.status == ReminderStatus.late
                            ? AppColors.error
                            : widget.iconColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: widget.status == ReminderStatus.done
                              ? AppColors.onSurfaceVariant
                              : widget.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PeriodHelper.getPeriodIconFromStr(widget.time),
                                size: 24,
                                color: widget.status == ReminderStatus.late
                                    ? AppColors.error
                                    : widget.status == ReminderStatus.done
                                        ? AppColors.onSurfaceVariant
                                        : PeriodHelper.getPeriodColorFromStr(widget.time, widget.accentColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                PeriodHelper.getPeriodLabelFromStr(widget.time),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  color: widget.status == ReminderStatus.late
                                      ? AppColors.error
                                      : widget.status == ReminderStatus.done
                                          ? AppColors.onSurfaceVariant
                                          : PeriodHelper.getPeriodColorFromStr(widget.time, widget.accentColor),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.time,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.status == ReminderStatus.done
                                  ? AppColors.tertiaryFixedDim.withValues(alpha: 0.2)
                                  : widget.status == ReminderStatus.late
                                      ? AppColors.error.withValues(alpha: 0.15)
                                      : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: widget.status == ReminderStatus.done
                                    ? AppColors.tertiaryFixedDim
                                    : widget.status == ReminderStatus.late
                                        ? AppColors.error
                                        : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.status == ReminderStatus.done
                                  ? 'Tudo certo!'
                                  : widget.status == ReminderStatus.late
                                      ? 'Atrasado'
                                      : 'Falta fazer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: widget.status == ReminderStatus.done
                                    ? AppColors.onTertiaryFixedVariant
                                    : widget.status == ReminderStatus.late
                                        ? AppColors.error
                                        : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.status == ReminderStatus.done
                          ? AppColors.tertiaryFixedDim.withValues(alpha: 0.2)
                          : widget.accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying || _isSpeaking
                          ? Icons.stop
                          : Icons.play_arrow,
                      color: widget.status == ReminderStatus.done
                          ? AppColors.onTertiaryFixedVariant
                          : widget.accentColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.status == ReminderStatus.done
                          ? Icons.check_circle
                          : widget.status == ReminderStatus.late
                              ? Icons.error_outline
                              : Icons.circle_outlined,
                      color: widget.status == ReminderStatus.done
                          ? AppColors.onTertiaryFixedVariant
                          : widget.status == ReminderStatus.late
                              ? AppColors.error
                              : AppColors.outline,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isPlaying || _isSpeaking) ...[
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
                        final animOffset = sin(_waveController.value * pi * 2 + seed) * 0.3;
                        final heightFactor = (baseHeight + animOffset).clamp(0.1, 1.0);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: 32 * heightFactor,
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
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Falando...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
