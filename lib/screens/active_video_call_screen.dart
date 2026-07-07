import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  final String callId;
  final String roomName;

  const ActiveVideoCallScreen({
    super.key,
    required this.callId,
    required this.roomName,
  });

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen>
    with WidgetsBindingObserver {
  lk.Room? _room;
  lk.LocalParticipant? _localParticipant;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _useFrontCamera = true;
  Timer? _durationTimer;
  int _durationSeconds = 0;
  String _remoteName = '...';
  List<lk.RemoteVideoTrack> _remoteTracks = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRemoteName();
    _connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isConnected) {}
  }

  Future<void> _loadRemoteName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (SessionRoleService.isElderly) {
        final nome = prefs.getString('caregiver_name') ?? 'Cuidador';
        if (mounted) setState(() => _remoteName = nome);
      } else {
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
              _remoteName = doc.data()?['nome'] as String? ?? 'Idoso';
            });
            return;
          }
        }
        final nome = prefs.getString('idoso_nome') ?? 'Idoso';
        if (mounted) setState(() => _remoteName = nome);
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    final identity = await VideoCallService.instance.getMyIdentity();
    final tokenData = await VideoCallService.instance.generateToken(
      roomName: widget.roomName,
      identity: identity,
    );

    if (tokenData == null || tokenData.token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao conectar. Verifique sua internet.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      _room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      _room!.events.on<lk.TrackSubscribedEvent>((event) {
        if (event.track is lk.RemoteVideoTrack && mounted) {
          setState(() {
            _remoteTracks.add(event.track as lk.RemoteVideoTrack);
          });
        }
      });

      _room!.events.on<lk.TrackUnsubscribedEvent>((event) {
        if (event.track is lk.RemoteVideoTrack && mounted) {
          setState(() {
            _remoteTracks.remove(event.track);
          });
        }
      });

      _room!.events.on<lk.ParticipantConnectedEvent>((event) {
        // Participante remoto conectou
      });

      _room!.events.on<lk.ParticipantDisconnectedEvent>((event) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_remoteName saiu da chamada.')),
          );
          _endCall();
        }
      });

      _room!.events.on<lk.RoomDisconnectedEvent>((event) {
        if (mounted) _endCall();
      });

      await _room!.connect(
        tokenData.serverUrl,
        tokenData.token,
      );

      _localParticipant = _room!.localParticipant;
      if (_localParticipant != null) {
        await _localParticipant!.setCameraEnabled(true);
        await _localParticipant!.setMicrophoneEnabled(true);
      }

      if (mounted) {
        setState(() => _isConnected = true);
        _startDurationTimer();
      }
    } catch (e) {
      debugPrint('Erro ao conectar no LiveKit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao conectar na chamada.')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  Future<void> _toggleMute() async {
    if (_localParticipant == null) return;
    _isMuted = !_isMuted;
    await _localParticipant!.setMicrophoneEnabled(!_isMuted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_localParticipant == null) return;
    _isCameraOn = !_isCameraOn;
    await _localParticipant!.setCameraEnabled(_isCameraOn);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_localParticipant == null) return;
    _useFrontCamera = !_useFrontCamera;
    // LiveKit lida com troca de câmera internamente
    if (mounted) setState(() {});
  }

  Future<void> _endCall() async {
    await _disconnect();
    await VideoCallService.instance.endCall(
      widget.callId,
      durationSeconds: _durationSeconds,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _disconnect() async {
    try {
      await _room?.disconnect();
    } catch (_) {}
    _room = null;
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video - full screen
            if (_remoteTracks.isNotEmpty)
              Positioned.fill(
                child: lk.VideoTrackRenderer(
                  _remoteTracks.first,
                  fit: lk.VideoViewFit.contain,
                ),
              )
            else
              Positioned.fill(
                child: _RemoteParticipantPlaceholder(
                  name: _remoteName,
                  isElderly: isElderly,
                ),
              ),

            // Local video - PiP
            Positioned(
              top: 16,
              right: 16,
              child: _LocalVideoPreview(
                isCameraOn: _isCameraOn,
                room: _room,
                size: isElderly ? 100 : 120,
              ),
            ),

            // Top info bar
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _remoteName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(_durationSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: isElderly ? 40 : 24,
              left: 0,
              right: 0,
              child: _CallControls(
                isElderly: isElderly,
                isMuted: _isMuted,
                isCameraOn: _isCameraOn,
                onToggleMute: _toggleMute,
                onToggleCamera: _toggleCamera,
                onSwitchCamera: _switchCamera,
                onEndCall: _endCall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteParticipantPlaceholder extends StatelessWidget {
  final String name;
  final bool isElderly;

  const _RemoteParticipantPlaceholder({
    required this.name,
    required this.isElderly,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isElderly ? 140 : 100,
              height: isElderly ? 140 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: Icon(
                Icons.person,
                size: isElderly ? 80 : 60,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: isElderly ? 28 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conectando...',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalVideoPreview extends StatelessWidget {
  final bool isCameraOn;
  final lk.Room? room;
  final double size;

  const _LocalVideoPreview({
    required this.isCameraOn,
    this.room,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final localTrack = room?.localParticipant?.videoTrackPublications
        .firstOrNull
        ?.track;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size * 1.33,
        color: Colors.black54,
        child: isCameraOn && localTrack != null
            ? lk.VideoTrackRenderer(
                localTrack,
                fit: lk.VideoViewFit.cover,
                mirrorMode: lk.VideoViewMirrorMode.mirror,
              )
            : Icon(
                Icons.person_off,
                color: Colors.white38,
                size: size * 0.4,
              ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  final bool isElderly;
  final bool isMuted;
  final bool isCameraOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEndCall;

  const _CallControls({
    required this.isElderly,
    required this.isMuted,
    required this.isCameraOn,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = isElderly ? 64.0 : 52.0;
    final iconSize = isElderly ? 28.0 : 22.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlBtn(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            color: isMuted ? Colors.red : Colors.white24,
            size: btnSize,
            iconSize: iconSize,
            onPressed: onToggleMute,
          ),
          const SizedBox(width: 16),

          _ControlBtn(
            icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
            color: isCameraOn ? Colors.white24 : Colors.red,
            size: btnSize,
            iconSize: iconSize,
            onPressed: onToggleCamera,
          ),
          const SizedBox(width: 16),

          if (!isElderly)
            _ControlBtn(
              icon: Icons.flip_camera_android,
              color: Colors.white24,
              size: btnSize,
              iconSize: iconSize,
              onPressed: onSwitchCamera,
            ),
          if (!isElderly) const SizedBox(width: 16),

          Container(
            width: btnSize * 1.5,
            height: btnSize * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onEndCall,
              icon: const Icon(Icons.call_end, color: Colors.white),
              iconSize: iconSize * 1.3,
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: iconSize,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
