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
      VideoCallService.instance.markMissedCallsAsRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _callsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startCall(String type) async {
    final idosoId = await SessionRoleService.getActiveIdosoId();
    final call = await VideoCallService.instance.initiateCall(
      idosoId: idosoId,
      callType: type,
      initiatedBy: SessionRoleService.isSupervisor ? 'supervisor' : 'idoso',
    );
    if (call != null && mounted) {
      await VideoCallService.instance.joinCall(
        call.roomName,
        callType: type,
        callId: call.callId,
        alreadyVerified: true,
      );
    }
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Hoje';
    } else if (itemDate == yesterday) {
      return 'Ontem';
    } else {
      final d = itemDate.day.toString().padLeft(2, '0');
      final m = itemDate.month.toString().padLeft(2, '0');
      final y = itemDate.year;
      return '$d/$m/$y';
    }
  }

  List<Widget> _buildGroupedList(bool isElderly) {
    final List<Widget> items = [];
    String? lastHeader;

    for (var i = 0; i < _calls.length; i++) {
      final call = _calls[i];
      final header = _getDateHeader(call.startedAt);

      if (header != lastHeader) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
        lastHeader = header;
      }

      items.add(
        _CallHistoryTile(
          call: call,
          isElderly: isElderly,
          onCallBack: (type) => _startCall(type),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;

    return Scaffold(
      appBar: AppBar(
        title: Text(isElderly ? 'Ligações' : 'Ligações de Voz e Vídeo'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _calls.isEmpty
            ? _EmptyState(
                isElderly: isElderly,
                onStartCall: () => _startCall('video'),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: _buildGroupedList(isElderly),
              ),
      ),
      floatingActionButton: isElderly
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fab_voice',
                  onPressed: () => _startCall('voice'),
                  icon: const Icon(Icons.phone),
                  label: const Text('Ligação Voz'),
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'fab_video',
                  onPressed: () => _startCall('video'),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Ligação Imagem'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ],
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
              Icons.phone_disabled_outlined,
              size: 80,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma ligação ainda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isElderly ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (!isElderly) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onStartCall,
                icon: const Icon(Icons.videocam),
                label: const Text('Iniciar Ligação'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
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
  final bool isElderly;
  final Function(String) onCallBack;

  const _CallHistoryTile({
    required this.call,
    required this.isElderly,
    required this.onCallBack,
  });

  Future<void> _confirmDeleteCall(BuildContext context, String callId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Apagar Ligação',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Tem certeza que deseja apagar este registro do histórico de ligações?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await VideoCallService.instance.deleteCall(callId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Ligação apagada do histórico.'
                  : 'Não foi possível apagar a ligação.',
            ),
            backgroundColor: success ? AppColors.primary : AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSos = call.isFromSos;
    final isMissed =
        call.status == VideoCallStatus.missed ||
        call.status == VideoCallStatus.declined;

    Color iconBgColor;
    IconData callIcon;
    Color cardBgColor;
    Color borderColor;
    String statusLabel;
    Color statusColor;

    if (isSos) {
      iconBgColor = AppColors.error;
      callIcon = Icons.warning_amber_rounded;
      cardBgColor = AppColors.errorContainer.withValues(alpha: 0.35);
      borderColor = AppColors.error.withValues(alpha: 0.5);
      statusLabel = 'Emergência SOS';
      statusColor = AppColors.error;
    } else if (isMissed) {
      iconBgColor = AppColors.error;
      callIcon = Icons.phone_missed_rounded;
      cardBgColor = AppColors.errorContainer.withValues(alpha: 0.18);
      borderColor = AppColors.error.withValues(alpha: 0.35);
      statusLabel = call.status == VideoCallStatus.declined
          ? 'Recusada'
          : 'Não Atendida';
      statusColor = AppColors.error;
    } else {
      iconBgColor = AppColors.onCustomContainer;
      callIcon = call.isVoiceCall
          ? Icons.phone_callback_rounded
          : Icons.video_camera_back_rounded;
      cardBgColor = AppColors.customContainer.withValues(alpha: 0.35);
      borderColor = AppColors.customContainer;
      statusLabel = 'Atendida • Concluída';
      statusColor = AppColors.onCustomContainer;
    }

    return Card(
      color: cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: Container(
            width: isElderly ? 56 : 48,
            height: isElderly ? 56 : 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              callIcon,
              color: Colors.white,
              size: isElderly ? 32 : 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  call.isFromSupervisor
                      ? 'Ligação do Cuidador'
                      : 'Ligação do Idoso',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: isElderly ? 20 : 16,
                  ),
                ),
              ),
              if (isSos)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: isElderly ? 15 : 13,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${call.formattedStartTime} • Tempo: ${call.formattedDetailedDuration}',
                  style: TextStyle(
                    fontSize: isElderly ? 15 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => onCallBack(call.callType),
                icon: Icon(
                  call.isVoiceCall ? Icons.phone : Icons.videocam,
                  size: isElderly ? 24 : 18,
                ),
                label: Text(
                  'Ligar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isElderly ? 16 : 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isElderly ? 16 : 12,
                    vertical: isElderly ? 12 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: isElderly ? 26 : 22,
                ),
                tooltip: 'Apagar ligação',
                onPressed: () => _confirmDeleteCall(context, call.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
