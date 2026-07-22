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
          final profile =
              await ElderlyProfileRepository.instance.getData(idosoId);
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
          final data =
              await ElderlyProfileRepository.instance.getData(idosoId);
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
    final isHighContrast =
        Theme.of(context).brightness == Brightness.light &&
        Theme.of(context).colorScheme.primary == Colors.black;

    final isVoice = widget.callType == 'voice';

    return Scaffold(
      backgroundColor: isHighContrast ? Colors.black : const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // SOS Alert banner if SOS
                if (_isSosCall)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ALERTA DE EMERGÊNCIA SOS!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Pulsing Avatar Ripple
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: isElderly ? 180 : 140,
                      height: isElderly ? 180 : 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isSosCall
                                        ? AppColors.error
                                        : AppColors.primary)
                                    .withValues(
                                      alpha:
                                          0.2 * (1.0 - _pulseController.value),
                                    ),
                            blurRadius: 30 * _pulseController.value,
                            spreadRadius: 25 * _pulseController.value,
                          ),
                          BoxShadow(
                            color:
                                (_isSosCall
                                        ? AppColors.error
                                        : AppColors.primary)
                                    .withValues(
                                      alpha:
                                          0.3 * (1.0 - _pulseController.value),
                                    ),
                            blurRadius: 15 * _pulseController.value,
                            spreadRadius: 10 * _pulseController.value,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E1E),
                      border: Border.all(
                        color: _isSosCall ? AppColors.error : AppColors.primary,
                        width: 5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isVoice ? Icons.phone_in_talk : Icons.videocam,
                        size: isElderly ? 80 : 60,
                        color: _isSosCall ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Caller name
                Text(
                  _callerName.isNotEmpty
                      ? _callerName
                      : (isVoice ? 'Ligação de Voz' : 'Ligação com Imagem'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isElderly ? 36 : 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Badge Call Type Description
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isVoice
                        ? const Color(0xFF1A237E)
                        : const Color(0xFF006064),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVoice ? 'LIGAÇÃO SÓ COM SOM' : 'LIGAÇÃO COM IMAGEM',
                    style: TextStyle(
                      fontSize: isElderly ? 18 : 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Instruction tip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Toque no botão VERDE para atender ou VERMELHO para recusar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isElderly ? 18 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Accept / Decline buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decline
                    _CallActionButton(
                      icon: Icons.call_end,
                      label: 'Recusar',
                      color: AppColors.error,
                      onPressed: _accepted ? null : _decline,
                      large: isElderly,
                    ),
                    const SizedBox(width: 48),
                    // Accept
                    _CallActionButton(
                      icon: isVoice ? Icons.phone : Icons.videocam,
                      label: 'Atender',
                      color: const Color(0xFF2E7D32),
                      onPressed: _accepted ? null : _accept,
                      large: isElderly,
                    ),
                  ],
                ),

                const Spacer(flex: 2),
              ],
            ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 20 : 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
