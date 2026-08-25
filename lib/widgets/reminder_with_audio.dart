import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/audio_path_helper.dart';
import '../utils/period_helper.dart';
import '../utils/reminder_state_helper.dart';
import 'audio_manager.dart';
import 'alex_avatar.dart';

export '../utils/reminder_state_helper.dart';

class ReminderWithAudio extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String time;
  final VoidCallback onTap;
  final VoidCallback? onStatusTap;
  final ReminderStatus status;
  final Color? _accentColor;
  Color get accentColor => _accentColor ?? AppColors.primary;
  final String? audioPath;
  final String? ttsText;
  final String? dosage;
  final String? instructions;
  final bool requiresPhoto;
  final String? relativeTime;

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
    Color? accentColor,
    this.audioPath,
    this.ttsText,
    this.dosage,
    this.instructions,
    this.requiresPhoto = false,
    this.relativeTime,
  }) : _accentColor = accentColor;

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
      final texto =
          widget.ttsText ??
          '${widget.title} ${PeriodHelper.getSpokenTimeWithPrepositionFromStr(widget.time)}';
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
    final isDoneStatus =
        widget.status == ReminderStatus.done ||
        widget.status == ReminderStatus.doneWithPhoto ||
        widget.status == ReminderStatus.caregiverConfirmed;
    final isPostponed = widget.status == ReminderStatus.postponed;
    final isAttentionStatus =
        widget.status == ReminderStatus.late ||
        widget.status == ReminderStatus.missed ||
        widget.status == ReminderStatus.needsHelp;

    final Color sideBarColor = isDoneStatus
        ? AppColors.success
        : isAttentionStatus
        ? AppColors.error
        : isPostponed
        ? AppColors.warning
        : widget.accentColor;

    final Color cardBg = isDoneStatus
        ? AppColors.successContainer.withValues(alpha: 0.35)
        : isPostponed
        ? AppColors.warningContainer.withValues(alpha: 0.35)
        : isAttentionStatus
        ? AppColors.errorContainer.withValues(alpha: 0.35)
        : AppColors.surfaceContainerLowest;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDoneStatus
              ? AppColors.success.withValues(alpha: 0.4)
              : isAttentionStatus
              ? AppColors.error
              : isPostponed
              ? AppColors.warning.withValues(alpha: 0.5)
              : widget.accentColor.withValues(alpha: 0.25),
          width: isAttentionStatus ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Cor Lateral
              Container(width: 8, color: sideBarColor),

              // Conteúdo do Card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Área Superior do Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícone da Categoria
                          GestureDetector(
                            onTap: widget.onTap,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDoneStatus
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : isAttentionStatus
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : isPostponed
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : widget.iconBg.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon,
                                color: isDoneStatus
                                    ? AppColors.success
                                    : isAttentionStatus
                                    ? AppColors.error
                                    : isPostponed
                                    ? AppColors.warning
                                    : widget.accentColor,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Título e Badges
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onTap,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Título do Lembrete
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      color: isDoneStatus
                                          ? AppColors.onSurfaceVariant
                                          : isAttentionStatus
                                          ? AppColors.error
                                          : AppColors.onSurface,
                                      decoration: isDoneStatus
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Linha de Chips / Badges
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      // Chip Horário + Período
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.outlineVariant,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              PeriodHelper.getPeriodIconFromStr(
                                                widget.time,
                                              ),
                                              size: 15,
                                              color: PeriodHelper.getPeriodColorFromStr(
                                                widget.time,
                                                widget.accentColor,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.time,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Chip Tempo Relativo
                                      if (widget.relativeTime != null &&
                                          widget.relativeTime!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDoneStatus
                                                ? AppColors.successContainer
                                                : isAttentionStatus
                                                ? AppColors.errorContainer
                                                : isPostponed
                                                ? AppColors.warningContainer
                                                : AppColors.primaryContainer.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            widget.relativeTime!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDoneStatus
                                                  ? AppColors.onSuccessContainer
                                                  : isAttentionStatus
                                                  ? AppColors.onErrorContainer
                                                  : isPostponed
                                                  ? AppColors.onWarningContainer
                                                  : AppColors.primary,
                                            ),
                                          ),
                                        ),

                                      // Chip de Dosagem
                                      if (widget.dosage != null &&
                                          widget.dosage!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.medicationContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.medication,
                                                size: 13,
                                                color: AppColors.onMedicationContainer,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                widget.dosage!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.onMedicationContainer,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Badge de Foto Obrigatória
                                      if (widget.requiresPhoto && !isDoneStatus)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.infoContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.camera_alt,
                                                size: 13,
                                                color: AppColors.info,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Exige foto',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.info,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Box de Instruções
                                  if (widget.instructions != null &&
                                      widget.instructions!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.outlineVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.tips_and_updates_outlined,
                                            size: 15,
                                            color: widget.accentColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.instructions!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Barra Inferior de Ações (Ouvir + Adiar + Ação Principal)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                      child: Row(
                        children: [
                          // Botão Ouvir Lembrete
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _togglePlay,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _isPlaying || _isSpeaking
                                      ? AppColors.errorContainer.withValues(
                                          alpha: 0.3,
                                        )
                                      : AppColors.surfaceContainerLow,
                                  side: BorderSide(
                                    color: _isPlaying || _isSpeaking
                                        ? AppColors.error
                                        : AppColors.outlineVariant,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isPlaying || _isSpeaking
                                          ? Icons.stop_circle
                                          : Icons.volume_up,
                                      size: 20,
                                      color: _isPlaying || _isSpeaking
                                          ? AppColors.error
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _isPlaying || _isSpeaking
                                            ? 'Parar'
                                            : 'Ouvir',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _isPlaying || _isSpeaking
                                              ? AppColors.error
                                              : AppColors.primary,
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

                          // Botão de Ação Principal
                          if (widget.onStatusTap != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onStatusTap!();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDoneStatus
                                        ? AppColors.success
                                        : isAttentionStatus
                                        ? AppColors.error
                                        : widget.requiresPhoto
                                        ? AppColors.primary
                                        : AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isDoneStatus
                                            ? Icons.check_circle
                                            : widget.requiresPhoto
                                            ? Icons.camera_alt
                                            : isAttentionStatus
                                            ? Icons.priority_high
                                            : Icons.check,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          isDoneStatus
                                              ? 'Concluído'
                                              : widget.requiresPhoto
                                              ? 'Fotografar'
                                              : isAttentionStatus
                                              ? 'Tomar agora'
                                              : 'Feito',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
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
                    ),

                    // Animação de Onda de Áudio / Avatar Alex
                    if (_isPlaying || _isSpeaking) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return SizedBox(
                              height: 28,
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
                                        height: 28 * heightFactor,
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
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AlexAvatar(size: 54, animate: true),
                        ),
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
