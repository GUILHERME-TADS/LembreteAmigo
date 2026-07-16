import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/audio_path_helper.dart';
import '../utils/period_helper.dart';
import '../utils/reminder_state_helper.dart';
import 'audio_manager.dart';
import 'reminder_status_badge.dart';
import 'alex_avatar.dart';

export '../utils/reminder_state_helper.dart';

LembreteStatus _getLembreteStatus(ReminderStatus status) {
  switch (status) {
    case ReminderStatus.done:
      return LembreteStatus.concluido;
    case ReminderStatus.late:
    case ReminderStatus.missed:
      return LembreteStatus.perdido;
    case ReminderStatus.postponed:
      return LembreteStatus.adiado;
    case ReminderStatus.scheduled:
      return LembreteStatus.pendente;
  }
}

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
  final String? ttsText;

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
    this.ttsText,
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
        TTSService.instance.parar(caller: this);
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
    TTSService.instance.parar(caller: this);
    _waveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (widget.audioPath != null && widget.audioPath != 'ia_generated') {
      if (_isPlaying) {
        _audioPlayer.stop();
        _onAudioComplete();
      } else {
        if (_isSpeaking) {
          TTSService.instance.parar(caller: this);
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
      await TTSService.instance.parar(caller: this);
      _waveController.stop();
      _waveController.reset();
      AudioManager.stopPlay(audioId);
      setState(() => _isSpeaking = false);
    } else {
      if (!AudioManager.requestPlay(audioId)) return;
      setState(() => _isSpeaking = true);
      _waveController.repeat(reverse: true);
      final texto = widget.ttsText ?? '${widget.title} às ${PeriodHelper.getSpokenTimeFromStr(widget.time)}';
      await TTSService.instance.falar(texto, caller: this);
      _waveController.stop();
      _waveController.reset();
      AudioManager.stopPlay(audioId);
      if (mounted) setState(() => _isSpeaking = false);
    }
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
    final isHighContrast = Theme.of(context).colorScheme.primary == Colors.black;
    final Color sideBarColor = widget.status == ReminderStatus.done
        ? AppColors.tertiaryFixedDim
        : widget.status == ReminderStatus.late
        ? AppColors.error
        : widget.status == ReminderStatus.postponed
        ? AppColors.secondaryFixedDim
        : widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: widget.status == ReminderStatus.done
            ? const Color(0xFFE8F5E9)
            : widget.status == ReminderStatus.postponed
            ? const Color(0xFFFFFDE7)
            : AppColors.surfaceContainerLowest,
        border: Border.all(
          color: widget.status == ReminderStatus.done
              ? AppColors.tertiaryFixedDim.withValues(alpha: 0.5)
              : widget.status == ReminderStatus.late
              ? AppColors.error
              : widget.status == ReminderStatus.postponed
              ? AppColors.secondaryFixedDim.withValues(alpha: 0.5)
              : widget.accentColor.withValues(alpha: 0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 12, color: sideBarColor),
              Expanded(
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
                                  ? AppColors.tertiaryFixedDim.withValues(
                                      alpha: 0.3,
                                    )
                                  : widget.status == ReminderStatus.late
                                  ? AppColors.error.withValues(alpha: 0.15)
                                  : widget.status == ReminderStatus.postponed
                                  ? AppColors.secondaryFixed.withValues(
                                      alpha: 0.3,
                                    )
                                  : widget.iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.status == ReminderStatus.done
                                  ? AppColors.onTertiaryFixedVariant
                                  : widget.status == ReminderStatus.late
                                  ? AppColors.error
                                  : widget.status == ReminderStatus.postponed
                                  ? AppColors.onSecondaryFixedVariant
                                  : widget.iconColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: _togglePlay,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color:
                                          widget.status == ReminderStatus.done
                                          ? AppColors.onSurfaceVariant
                                          : widget.status ==
                                                ReminderStatus.postponed
                                          ? AppColors.onSecondaryFixedVariant
                                          : widget.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            PeriodHelper.getPeriodIconFromStr(
                                              widget.time,
                                            ),
                                            size: 32,
                                            color:
                                                PeriodHelper.getPeriodColorFromStr(
                                                  widget.time,
                                                  widget.accentColor,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  PeriodHelper.getPeriodColorFromStr(
                                                    widget.time,
                                                    widget.accentColor,
                                                  ).withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              widget.time,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    PeriodHelper.getPeriodColorFromStr(
                                                      widget.time,
                                                      widget.accentColor,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ReminderStatusBadge(
                                        status: _getLembreteStatus(
                                          widget.status,
                                        ),
                                        compact: true,
                                        accentColor: widget.accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _isPlaying || _isSpeaking
                                    ? (widget.status == ReminderStatus.done
                                          ? AppColors.tertiaryFixedDim
                                          : widget.status ==
                                                ReminderStatus.postponed
                                          ? AppColors.secondaryFixed
                                          : widget.accentColor.withValues(
                                              alpha: 0.2,
                                            ))
                                    : widget.accentColor.withValues(alpha: 0.1),
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: widget.status == ReminderStatus.done
                                      ? AppColors.onTertiaryFixedVariant
                                      : widget.status ==
                                            ReminderStatus.postponed
                                      ? AppColors.onSecondaryFixedVariant
                                      : widget.accentColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                _isPlaying || _isSpeaking
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                color: widget.status == ReminderStatus.done
                                    ? AppColors.onTertiaryFixedVariant
                                    : widget.status == ReminderStatus.postponed
                                    ? AppColors.onSecondaryFixedVariant
                                    : widget.accentColor,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: (widget.status == ReminderStatus.done ||
                                    widget.status == ReminderStatus.postponed ||
                                    widget.status == ReminderStatus.missed)
                                ? null
                                : widget.onTap,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: (widget.status == ReminderStatus.done ||
                                        widget.status == ReminderStatus.postponed ||
                                        widget.status == ReminderStatus.missed)
                                    ? Colors.transparent
                                    : widget.accentColor.withValues(alpha: 0.1),
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: (widget.status == ReminderStatus.done ||
                                          widget.status == ReminderStatus.postponed ||
                                          widget.status == ReminderStatus.missed)
                                      ? Colors.transparent
                                      : widget.accentColor,
                                  width: (widget.status == ReminderStatus.done ||
                                          widget.status == ReminderStatus.postponed ||
                                          widget.status == ReminderStatus.missed)
                                      ? 0
                                      : 3,
                                ),
                              ),
                              child: widget.status == ReminderStatus.done ||
                                      widget.status == ReminderStatus.postponed ||
                                      widget.status == ReminderStatus.late ||
                                      widget.status == ReminderStatus.missed
                                  ? Icon(
                                      widget.status == ReminderStatus.done
                                          ? Icons.check
                                          : widget.status == ReminderStatus.postponed
                                              ? Icons.schedule
                                              : widget.status == ReminderStatus.missed
                                                  ? Icons.close
                                                  : Icons.priority_high,
                                      color: widget.status == ReminderStatus.done
                                          ? const Color(0xFF005312)
                                          : widget.status == ReminderStatus.postponed
                                              ? const Color(0xFF827717)
                                              : AppColors.error,
                                      size: 32,
                                    )
                                  : Icon(
                                      Icons.radio_button_unchecked,
                                      color: isHighContrast ? Colors.black : widget.accentColor,
                                      size: 32,
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
                                  final baseHeight =
                                      0.15 + (sin(seed) * 0.5 + 0.5) * 0.7;
                                  final animOffset =
                                      sin(
                                        _waveController.value * pi * 2 + seed,
                                      ) *
                                      0.3;
                                  final heightFactor = (baseHeight + animOffset)
                                      .clamp(0.1, 1.0);
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Container(
                                        height: 32 * heightFactor,
                                        decoration: BoxDecoration(
                                          color: widget.accentColor.withValues(
                                            alpha: 0.4 + heightFactor * 0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
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
                        child: AlexAvatar(size: 60, animate: true),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
