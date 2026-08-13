import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import '../models/video_call.dart';
import '../services/presence_service.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/video_call_service.dart';
import '../widgets/elderly_profile_avatar.dart';
import '../widgets/missed_calls_badge.dart';
import '../widgets/supervisor_drawer.dart';

class SupervisorCallScreen extends StatefulWidget {
  const SupervisorCallScreen({super.key});

  @override
  State<SupervisorCallScreen> createState() => _SupervisorCallScreenState();
}

class _SupervisorCallScreenState extends State<SupervisorCallScreen> {
  String _idosoId = '';
  String _idosoNome = 'Meu Idoso';
  String? _idosoFoto;
  bool _isLoading = true;
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    _loadIdosoInfo();
  }

  Future<void> _loadIdosoInfo() async {
    try {
      final activeIdosoId = await SessionRoleService.getActiveIdosoId();
      _idosoId = activeIdosoId;

      if (activeIdosoId.isNotEmpty) {
        final profile = await ElderlyProfileRepository.instance.getData(
          activeIdosoId,
        );
        if (profile != null) {
          _idosoNome = profile['nome'] as String? ?? 'Meu Idoso';
          _idosoFoto =
              (profile['fotoPath'] as String?) ??
              (profile['fotoUrl'] as String?) ??
              (profile['foto'] as String?);
        } else {
          final doc = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(activeIdosoId)
              .get();

          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            _idosoNome = data['nome'] as String? ?? 'Meu Idoso';
            _idosoFoto =
                (data['fotoPath'] as String?) ??
                (data['fotoUrl'] as String?) ??
                (data['foto'] as String?);
          }
        }
      }
      VideoCallService.instance.markMissedCallsAsRead();
    } catch (e) {
      debugPrint('Erro ao carregar idoso na tela de chamadas do cuidador: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _iniciarChamada(String callType) async {
    if (_isCalling) return;
    setState(() => _isCalling = true);

    try {
      if (_idosoId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nenhum idoso ativo selecionado para ligar.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final result = await VideoCallService.instance.initiateCall(
        idosoId: _idosoId,
        initiatedBy: 'supervisor',
        callType: callType,
      );

      if (result != null && mounted) {
        await VideoCallService.instance.joinCall(
          result.roomName,
          callType: callType,
          callId: result.callId,
        );
      } else if (mounted) {
        final msg =
            VideoCallService.instance.lastStartFailureMessage ??
            'Não foi possível conectar a chamada agora.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

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
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/supervisor-calls'),
      appBar: AppBar(
        title: const Text('Central de Ligações'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // CARD DO IDOSO CONECTADO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.outlineVariant,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        StreamBuilder<PresenceStatus>(
                          stream: PresenceService.instance.watchUserPresence(
                            userId: _idosoId,
                            isSupervisorTarget: false,
                          ),
                          builder: (context, snapshot) {
                            final presence = snapshot.data;
                            final isOnline = presence?.isOnline ?? false;
                            final statusText =
                                presence?.statusText ??
                                (isOnline ? 'Online' : 'Offline');

                            return Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    ElderlyProfileAvatar(
                                      fotoPath: _idosoFoto,
                                      size: 92,
                                      borderWidth: 3,
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? AppColors.success
                                            : AppColors.outline,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _idosoNome,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: isOnline
                                          ? AppColors.success
                                          : AppColors.outline,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isOnline
                                            ? AppColors.success
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // BOTÕES DE LIGAÇÃO
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCalling
                                    ? null
                                    : () => _iniciarChamada('video'),
                                icon: const Icon(Icons.videocam, size: 28),
                                label: const Text(
                                  'Vídeo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCalling
                                    ? null
                                    : () => _iniciarChamada('voice'),
                                icon: const Icon(Icons.phone, size: 28),
                                label: const Text(
                                  'Voz',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.onCustomContainer,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // HEADER DO HISTÓRICO RECENTE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          MissedCallsBadge(
                            child: Icon(
                              Icons.history,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Histórico Recente',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // LISTA DE CHAMADAS RECENTES
                  _idosoId.isEmpty
                      ? const Text('Nenhum idoso vinculado para ver histórico.')
                      : StreamBuilder<List<VideoCall>>(
                          stream: VideoCallService.instance.watchCallHistory(
                            _idosoId,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final calls = snapshot.data ?? [];
                            if (calls.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Nenhuma chamada registrada ainda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: calls.length > 10 ? 10 : calls.length,
                              itemBuilder: (context, index) {
                                final call = calls[index];
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
                                  cardBgColor = AppColors.errorContainer
                                      .withValues(alpha: 0.35);
                                  borderColor = AppColors.error.withValues(
                                    alpha: 0.5,
                                  );
                                  statusLabel = 'Emergência SOS';
                                  statusColor = AppColors.error;
                                } else if (isMissed) {
                                  iconBgColor = AppColors.error;
                                  callIcon = Icons.phone_missed_rounded;
                                  cardBgColor = AppColors.errorContainer
                                      .withValues(alpha: 0.18);
                                  borderColor = AppColors.error.withValues(
                                    alpha: 0.35,
                                  );
                                  statusLabel =
                                      call.status == VideoCallStatus.declined
                                      ? 'Recusada'
                                      : 'Não Atendida';
                                  statusColor = AppColors.error;
                                } else {
                                  iconBgColor = AppColors.onCustomContainer;
                                  callIcon = call.isVoiceCall
                                      ? Icons.phone_callback_rounded
                                      : Icons.video_camera_back_rounded;
                                  cardBgColor = AppColors.customContainer.withValues(
                                    alpha: 0.35,
                                  );
                                  borderColor = AppColors.customContainer;
                                  statusLabel = 'Atendida • Concluída';
                                  statusColor = AppColors.onCustomContainer;
                                }

                                return Card(
                                  color: cardBgColor,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                      leading: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: iconBgColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          callIcon,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              call.isFromSupervisor
                                                  ? 'Ligação para Idoso'
                                                  : 'Ligação do Idoso',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (isSos)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${call.formattedStartTime} • Tempo: ${call.formattedDetailedDuration}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _iniciarChamada(call.callType),
                                            icon: Icon(
                                              call.isVoiceCall
                                                  ? Icons.phone
                                                  : Icons.videocam,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Ligar',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.primary,
                                              side: BorderSide(
                                                color: AppColors.primary,
                                                width: 2,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.error,
                                              size: 22,
                                            ),
                                            tooltip: 'Apagar ligação',
                                            onPressed: () => _confirmDeleteCall(
                                              context,
                                              call.id,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
