import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
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

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen> {
  String _callerName = '';
  Timer? _vibrateTimer;
  bool _accepted = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _loadCallerName();
    VideoCallService.instance.watchCall(widget.callId);
    VideoCallService.instance.activeCallNotifier.addListener(_onActiveCallChanged);
    _startVibration();
  }

  void _startVibration() {
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.vibrate();
    });
  }

  void _onActiveCallChanged() {
    final activeCall = VideoCallService.instance.activeCallNotifier.value;
    if (activeCall == null ||
        activeCall.status == VideoCallStatus.ended ||
        activeCall.status == VideoCallStatus.declined) {
      _vibrateTimer?.cancel();
      if (mounted && !_accepted) {
        _leaveIncomingScreen();
      }
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

  @override
  void dispose() {
    VideoCallService.instance.activeCallNotifier.removeListener(_onActiveCallChanged);
    TTSService.instance.parar(caller: this);
    _vibrateTimer?.cancel();
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
          final perfilDoc = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .get();
          String? supervisorId =
              perfilDoc.data()?['supervisorId'] as String?;
          if (supervisorId == null || supervisorId.isEmpty) {
            final idosoDoc = await FirebaseFirestore.instance
                .collection('idosos')
                .doc(idosoId)
                .get();
            supervisorId = idosoDoc.data()?['supervisorId'] as String?;
          }

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

        if (mounted) setState(() => _callerName = nome);
      } else {
        // Busca nome do idoso
        final idosoId = await SessionRoleService.getActiveIdosoId();
        bool useFirebase = false;
        try {
          useFirebase = Firebase.apps.isNotEmpty;
        } catch (_) {}

        if (useFirebase) {
          final doc = await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .get();
          if (doc.exists && mounted) {
            setState(() {
              _callerName = doc.data()?['nome'] as String? ?? 'Idoso';
            });
            return;
          }
        }
        final nome = prefs.getString('idoso_nome') ?? 'Idoso';
        if (mounted) setState(() => _callerName = nome);
      }
    } catch (_) {}

    // TTS announce
    try {
      final isVoice = widget.callType == 'voice';
      final callName = isVoice ? 'voz' : 'vídeo';
      final msg = SessionRoleService.isElderly
          ? '$_callerName está chamando você por $callName! Toque no botão verde para atender.'
          : 'Chamada de $callName de $_callerName.';
      await TTSService.instance.falar(msg, caller: this);
    } catch (_) {}
  }

  Future<void> _accept() async {
    _vibrateTimer?.cancel();
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
    _vibrateTimer?.cancel();
    await VideoCallService.instance.declineCall(widget.callId);
    _leaveIncomingScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;
    final isHighContrast = Theme.of(context).brightness == Brightness.light &&
        Theme.of(context).colorScheme.primary == Colors.black;

    return Scaffold(
      backgroundColor: isHighContrast ? Colors.black : AppColors.primaryContainer,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Avatar
                Container(
                  width: isElderly ? 160 : 120,
                  height: isElderly ? 160 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHigh,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    widget.callType == 'voice' ? Icons.phone_in_talk : Icons.videocam,
                    size: isElderly ? 80 : 60,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // Caller name
                Text(
                  _callerName.isNotEmpty ? _callerName : (widget.callType == 'voice' ? 'Chamada de Voz' : 'Chamada de Vídeo'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isElderly ? 36 : 28,
                    fontWeight: FontWeight.w800,
                    color: isHighContrast ? Colors.white : AppColors.onPrimaryContainer,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.callType == 'voice' ? 'Chamada de Voz' : 'Chamada de Vídeo',
                  style: TextStyle(
                    fontSize: isElderly ? 24 : 18,
                    fontWeight: FontWeight.w600,
                    color: isHighContrast ? Colors.yellow : AppColors.onPrimaryContainer,
                  ),
                ),

                const Spacer(flex: 1),

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
                      icon: widget.callType == 'voice' ? Icons.phone : Icons.videocam,
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
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
