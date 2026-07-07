import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
import '../services/tts_service.dart';

class IncomingVideoCallScreen extends StatefulWidget {
  final String callId;
  final String roomName;

  const IncomingVideoCallScreen({
    super.key,
    required this.callId,
    required this.roomName,
  });

  @override
  State<IncomingVideoCallScreen> createState() =>
      _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen> {
  String _callerName = '';
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  Timer? _vibrateTimer;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadCallerName();
    _playRingtone();
    VideoCallService.instance.watchCall(widget.callId);
  }

  @override
  void dispose() {
    _ringtonePlayer.dispose();
    _vibrateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCallerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (SessionRoleService.isElderly) {
        // Busca nome do supervisor
        final nome = prefs.getString('caregiver_name') ?? 'Cuidador';
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
      final msg = SessionRoleService.isElderly
          ? '$_callerName está chamando você por vídeo! Toque no botão verde para atender.'
          : 'Chamada de vídeo de $_callerName.';
      await TTSService.instance.falar(msg);
    } catch (_) {}
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.play(
        AssetSource('sounds/ringtone.mp3'),
        volume: 1.0,
      );
    } catch (_) {
      // Ringtone asset opcional
    }
  }

  Future<void> _accept() async {
    setState(() => _accepted = true);
    await _ringtonePlayer.stop();
    await VideoCallService.instance.acceptCall(widget.callId);
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/active-video-call',
      arguments: {
        'callId': widget.callId,
        'roomName': widget.roomName,
      },
    );
  }

  Future<void> _decline() async {
    await _ringtonePlayer.stop();
    await VideoCallService.instance.declineCall(widget.callId);
    if (mounted) Navigator.pop(context);
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
                    Icons.videocam,
                    size: isElderly ? 80 : 60,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // Caller name
                Text(
                  _callerName.isNotEmpty ? _callerName : 'Chamada de Vídeo',
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
                  'Chamada de Vídeo',
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
                      icon: Icons.videocam,
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
