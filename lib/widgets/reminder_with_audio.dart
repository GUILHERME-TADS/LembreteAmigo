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
    case ReminderStatus.doneWithPhoto:
      return LembreteStatus.concluidoComFoto;
    case ReminderStatus.caregiverConfirmed:
      return LembreteStatus.confirmadoPeloCuidador;
    case ReminderStatus.late:
    case ReminderStatus.missed:
      return LembreteStatus.perdido;
    case ReminderStatus.needsHelp:
      return LembreteStatus.precisaDeAjuda;
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
  final VoidCallback? onStatusTap;
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
    this.onStatusTap,
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
      final texto = widget.ttsText ?? '${widget.title} ${PeriodHelper.getSpokenTimeWithPrepositionFromStr(widget.time)}';
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
    final isDoneStatus = widget.status == ReminderStatus.done ||
        widget.status == ReminderStatus.doneWithPhoto ||
        widget.status == ReminderStatus.caregiverConfirmed;
    final isPostponed = widget.status == ReminderStatus.postponed;
    final isAttentionStatus =
        widget.status == ReminderStatus.late ||
        widget.status == ReminderStatus.missed ||
        widget.status == ReminderStatus.needsHelp;
    final Color sideBarColor = isDoneStatus
        ? AppColors.tertiaryFixedDim
        : isAttentionStatus
        ? AppColors.error
        : isPostponed
        ? AppColors.secondaryFixedDim
        : widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: isDoneStatus
            ? const Color(0xFFE8F5E9)
            : isPostponed
            ? const Color(0xFFFFFDE7)
            : isAttentionStatus
            ? const Color(0xFFFFEBEE)
            : AppColors.surfaceContainerLowest,
        border: Border.all(
          color: isDoneStatus
              ? AppColors.tertiaryFixedDim.withValues(alpha: 0.5)
              : isAttentionStatus
              ? AppColors.error
              : isPostponed
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: widget.onTap,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDoneStatus
                                    ? AppColors.tertiaryFixedDim.withValues(
                                        alpha: 0.3,
                                      )
                                    : isAttentionStatus
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : isPostponed
                                    ? AppColors.secondaryFixed.withValues(
                                        alpha: 0.3,
                                      )
                                    : widget.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon,
                                color: isDoneStatus
                                    ? AppColors.onTertiaryFixedVariant
                                    : isAttentionStatus
                                    ? AppColors.error
                                    : isPostponed
                                    ? AppColors.onSecondaryFixedVariant
                                    : widget.iconColor,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: widget.onTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            height: 1.3,
                                            color:
                                                isDoneStatus
                                                ? AppColors.onSurfaceVariant
                                                : isPostponed
                                                ? AppColors.onSecondaryFixedVariant
                                                : isAttentionStatus
                                                ? AppColors.error
                                                : widget.accentColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: widget.onTap,
                                        behavior: HitTestBehavior.opaque,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
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
                                                const SizedBox(width: 8),
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
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: _togglePlay,
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: _isPlaying || _isSpeaking
                                                  ? (isDoneStatus
                                                        ? AppColors.tertiaryFixedDim
                                                        : isPostponed
                                                        ? AppColors.secondaryFixed
                                                        : isAttentionStatus
                                                        ? AppColors.error.withValues(alpha: 0.2)
                                                        : widget.accentColor.withValues(
                                                            alpha: 0.2,
                                                          ))
                                                  : widget.accentColor.withValues(alpha: 0.1),
                                              shape: BoxShape.rectangle,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isDoneStatus
                                                    ? AppColors.onTertiaryFixedVariant
                                                    : isPostponed
                                                    ? AppColors.onSecondaryFixedVariant
                                                    : isAttentionStatus
                                                    ? AppColors.error
                                                    : widget.accentColor,
                                                width: 3,
                                              ),
                                            ),
                                            child: Icon(
                                              _isPlaying || _isSpeaking
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                              color: isDoneStatus
                                                  ? AppColors.onTertiaryFixedVariant
                                                  : isPostponed
                                                  ? AppColors.onSecondaryFixedVariant
                                                  : isAttentionStatus
                                                  ? AppColors.error
                                                  : widget.accentColor,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: widget.onStatusTap ?? widget.onTap,
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: isDoneStatus
                                                  ? const Color(0xFFC8E6C9)
                                                  : isPostponed
                                                  ? const Color(0xFFFFF59D)
                                                  : isAttentionStatus
                                                  ? const Color(0xFFFFCDD2)
                                                  : widget.accentColor.withValues(alpha: 0.1),
                                              shape: BoxShape.rectangle,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isDoneStatus
                                                    ? const Color(0xFF388E3C)
                                                    : isPostponed
                                                    ? const Color(0xFFFBC02D)
                                                    : isAttentionStatus
                                                    ? AppColors.error
                                                    : widget.accentColor,
                                                width: 3,
                                              ),
                                            ),
                                            child: isDoneStatus ||
                                                    isPostponed ||
                                                    isAttentionStatus
                                                ? Icon(
                                                    isDoneStatus
                                                        ? Icons.check
                                                        : isPostponed
                                                            ? Icons.schedule
                                                            : widget.status == ReminderStatus.needsHelp
                                                                ? Icons.support_agent
                                                            : widget.status == ReminderStatus.missed
                                                                ? Icons.close
                                                                : Icons.priority_high,
                                                    color: isDoneStatus
                                                        ? const Color(0xFF005312)
                                                        : isPostponed
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
                                  ],
                                ),
                              ],
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
