import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/video_call_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../models/video_call.dart';
import '../widgets/responsive_layout.dart';

class IncomingVideoCallScreen extends StatefulWidget {
  final String callId;
  final String roomName;
  final String callType;

  const IncomingVideoCallScreen({
    super.key,
    required this.callId,
    required this.roomName,
    this.callType = 'video',
  });

  @override
  State<IncomingVideoCallScreen> createState() =>
      _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen>
    with SingleTickerProviderStateMixin {
  String _callerName = '';
  Timer? _vibrateTimer;
  Timer? _ttsTimer;
  bool _isSosCall = false;
  bool _accepted = false;
  bool _leaving = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadCallerName();
    VideoCallService.instance.watchCall(widget.callId);
    VideoCallService.instance.activeCallNotifier.addListener(
      _onActiveCallChanged,
    );
    _startVibration();
    _startTtsLoop();
  }

  void _startVibration() {
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.vibrate();
    });
  }

  void _startTtsLoop() {
    _ttsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _announceCall();
    });
  }

  void _announceCall() {
    try {
      final isVoice = widget.callType == 'voice';
      final msg = SessionRoleService.isElderly
          ? (isVoice
                ? '$_callerName quer falar com você. Toque no botão verde grande para atender.'
                : '$_callerName quer fazer uma ligação com imagem com você. Toque no botão verde grande para atender.')
          : (_isSosCall
                ? 'Atenção! Alerta de emergência! $_callerName está pedindo ajuda!'
                : 'Chamada de ${isVoice ? 'voz' : 'vídeo'} de $_callerName. Toque para atender.');
      TTSService.instance.falar(msg, caller: this);
    } catch (_) {}
  }

  void _onActiveCallChanged() {
    final activeCall = VideoCallService.instance.activeCallNotifier.value;
    if (activeCall == null ||
        activeCall.status == VideoCallStatus.ended ||
        activeCall.status == VideoCallStatus.declined) {
      _cleanupTimers();
      if (mounted && !_accepted) {
        _leaveIncomingScreen();
      }
    } else if (activeCall.initiatedBy == 'sos' && !_isSosCall) {
      setState(() {
        _isSosCall = true;
      });
    }
  }

  void _leaveIncomingScreen() {
    if (!mounted || _leaving) return;
    _leaving = true;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final fallbackRoute = SessionRoleService.isSupervisor
        ? '/supervisor-dashboard'
        : '/elderly-home';
    navigator.pushNamedAndRemoveUntil(fallbackRoute, (route) => false);
  }

  void _cleanupTimers() {
    _vibrateTimer?.cancel();
    _ttsTimer?.cancel();
  }

  @override
  void dispose() {
    VideoCallService.instance.activeCallNotifier.removeListener(
      _onActiveCallChanged,
    );
    TTSService.instance.parar(caller: this);
    _cleanupTimers();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCallerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (SessionRoleService.isElderly) {
        String nome = prefs.getString('caregiver_name') ?? 'Cuidador';
        bool useFirebase = false;
        try {
          useFirebase = Firebase.apps.isNotEmpty;
        } catch (_) {}

        if (useFirebase) {
          final idosoId = await SessionRoleService.getActiveIdosoId();
          final profile = await ElderlyProfileRepository.instance.getData(
            idosoId,
          );
          final supervisorId = profile?['supervisorId'] as String?;

          if (supervisorId != null && supervisorId.isNotEmpty) {
            final supervisorDoc = await FirebaseFirestore.instance
                .collection('supervisores')
                .doc(supervisorId)
                .get();
            final supervisorName = supervisorDoc.data()?['nome'] as String?;
            if (supervisorName != null && supervisorName.isNotEmpty) {
              nome = supervisorName;
              await prefs.setString('caregiver_name', supervisorName);
            }
          }
        }

        if (mounted) {
          setState(() {
            _callerName = nome;
          });
          _announceCall();
        }
      } else {
        // Busca nome do idoso
        final idosoId = await SessionRoleService.getActiveIdosoId();
        bool useFirebase = false;
        try {
          useFirebase = Firebase.apps.isNotEmpty;
        } catch (_) {}

        if (useFirebase) {
          final data = await ElderlyProfileRepository.instance.getData(idosoId);
          if (data != null && mounted) {
            setState(() {
              _callerName = data['nome'] as String? ?? 'Idoso';
            });
            _announceCall();
            return;
          }
        }
        final nome = prefs.getString('idoso_nome') ?? 'Idoso';
        if (mounted) {
          setState(() {
            _callerName = nome;
          });
          _announceCall();
        }
      }
    } catch (_) {}
  }

  Future<void> _accept() async {
    _cleanupTimers();
    await NotificationService.instance.cancelarChamada(widget.callId);
    setState(() => _accepted = true);
    await VideoCallService.instance.acceptCall(widget.callId);
    if (!mounted) return;
    _leaveIncomingScreen();
    await VideoCallService.instance.joinCall(
      widget.roomName,
      callType: widget.callType,
      callId: widget.callId,
      alreadyVerified: true,
    );
  }

  Future<void> _decline() async {
    _cleanupTimers();
    await NotificationService.instance.cancelarChamada(widget.callId);
    await VideoCallService.instance.declineCall(widget.callId);
    _leaveIncomingScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;
    final isVoice = widget.callType == 'voice';
    final compact = context.isCompactHeight || context.isLandscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          maxContentWidth: 720,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // SOS Alert banner if SOS
              if (_isSosCall)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ALERTA DE EMERGÊNCIA SOS!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Pulsing Avatar Ripple (Light Theme)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: compact ? 130 : (isElderly ? 190 : 150),
                    height: compact ? 130 : (isElderly ? 190 : 150),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isSosCall ? AppColors.error : AppColors.primary)
                                  .withValues(
                                    alpha: 0.25 * (1.0 - _pulseController.value),
                                  ),
                          blurRadius: 36 * _pulseController.value,
                          spreadRadius: 28 * _pulseController.value,
                        ),
                        BoxShadow(
                          color:
                              (_isSosCall ? AppColors.error : AppColors.primary)
                                  .withValues(
                                    alpha: 0.35 * (1.0 - _pulseController.value),
                                  ),
                          blurRadius: 18 * _pulseController.value,
                          spreadRadius: 12 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerLowest,
                    border: Border.all(
                      color: _isSosCall ? AppColors.error : AppColors.primary,
                      width: 6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isVoice ? Icons.phone_in_talk_rounded : Icons.videocam_rounded,
                      size: isElderly ? 84 : 64,
                      color: _isSosCall ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Caller name (High-contrast dark text on light background)
              Text(
                _callerName.isNotEmpty
                    ? _callerName
                    : (isVoice ? 'Ligação de Voz' : 'Ligação com Imagem'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isElderly ? 36 : 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Badge Call Type Description
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isVoice
                      ? AppColors.primaryContainer
                      : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVoice
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isVoice ? 'LIGAÇÃO SÓ COM SOM 🎙️' : 'LIGAÇÃO COM IMAGEM 📹',
                  style: TextStyle(
                    fontSize: isElderly ? 18 : 15,
                    fontWeight: FontWeight.w800,
                    color: isVoice
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSecondaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Instruction tip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Toque no botão VERDE para atender ou VERMELHO para recusar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isElderly ? 18 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Accept / Decline buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decline
                  _CallActionButton(
                    icon: Icons.call_end_rounded,
                    label: 'Recusar',
                    color: AppColors.error,
                    onPressed: _accepted ? null : _decline,
                    large: isElderly && !compact,
                  ),
                  SizedBox(width: compact ? 28 : 54),
                  // Accept
                  _CallActionButton(
                    icon: isVoice ? Icons.phone_rounded : Icons.videocam_rounded,
                    label: 'Atender',
                    color: AppColors.vitalHealthy,
                    onPressed: _accepted ? null : _accept,
                    large: isElderly && !compact,
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool large;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 96.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: large ? 40 : 32),
            style: IconButton.styleFrom(backgroundColor: Colors.transparent),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: large ? 112 : 88,
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: large ? 20 : 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
