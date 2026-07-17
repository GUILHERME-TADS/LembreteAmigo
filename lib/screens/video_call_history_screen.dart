import 'dart:async';

import 'package:flutter/material.dart';
import '../models/video_call.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
import '../theme/app_theme.dart';

class VideoCallHistoryScreen extends StatefulWidget {
  const VideoCallHistoryScreen({super.key});

  @override
  State<VideoCallHistoryScreen> createState() => _VideoCallHistoryScreenState();
}

class _VideoCallHistoryScreenState extends State<VideoCallHistoryScreen> {
  List<VideoCall> _calls = [];
  bool _loading = true;
  StreamSubscription<List<VideoCall>>? _callsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final idosoId = await SessionRoleService.getActiveIdosoId();
      await _callsSubscription?.cancel();
      _callsSubscription = VideoCallService.instance
          .watchCallHistory(idosoId)
          .listen((calls) {
        if (mounted) {
          setState(() {
            _calls = calls;
            _loading = false;
          });
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _callsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startCall() async {
    final idosoId = await SessionRoleService.getActiveIdosoId();
    final call = await VideoCallService.instance.initiateCall(
      idosoId: idosoId,
      callType: 'video',
    );
    if (call != null && mounted) {
      await VideoCallService.instance.joinCall(
        call.roomName,
        callType: 'video',
        callId: call.callId,
        alreadyVerified: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;

    return Scaffold(
      appBar: AppBar(
        title: Text(isElderly ? 'Chamadas de Vídeo' : 'Histórico de Chamadas'),
        actions: [
          if (!isElderly)
            IconButton(
              icon: const Icon(Icons.videocam),
              tooltip: 'Nova chamada',
              onPressed: _startCall,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _calls.isEmpty
                ? _EmptyState(isElderly: isElderly, onStartCall: _startCall)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _calls.length,
                    itemBuilder: (context, index) {
                      final call = _calls[index];
                      return _CallHistoryTile(call: call);
                    },
                  ),
      ),
      floatingActionButton: isElderly
          ? null
          : FloatingActionButton.extended(
              onPressed: _startCall,
              icon: const Icon(Icons.videocam),
              label: const Text('Chamada de Vídeo'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isElderly;
  final VoidCallback onStartCall;

  const _EmptyState({required this.isElderly, required this.onStartCall});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off,
              size: 80,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma chamada de vídeo realizada.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (!isElderly) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onStartCall,
                icon: const Icon(Icons.videocam),
                label: const Text('Iniciar Chamada'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final VideoCall call;

  const _CallHistoryTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final isSos = call.isFromSos;
    final isMissed = call.status == VideoCallStatus.missed ||
        call.status == VideoCallStatus.declined;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSos
              ? AppColors.error
              : isMissed
                  ? Colors.orange
                  : AppColors.primaryContainer,
          child: Icon(
            isSos
                ? Icons.warning
                : isMissed
                    ? Icons.call_missed
                    : Icons.videocam,
            color: isSos || isMissed ? Colors.white : AppColors.onPrimaryContainer,
          ),
        ),
        title: Text(
          call.isFromSupervisor ? 'Chamada do Cuidador' : 'Chamada do Idoso',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${call.formattedStartTime} • ${call.formattedDuration}',
        ),
        trailing: isSos
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
