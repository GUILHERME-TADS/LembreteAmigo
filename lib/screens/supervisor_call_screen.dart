import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../models/video_call.dart';
import '../services/session_role_service.dart';
import '../services/video_call_service.dart';
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
  bool _isOnline = false;
  bool _isLoading = true;
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    _loadIdosoInfo();
  }

  Future<void> _loadIdosoInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIdosoId = prefs.getString('active_idoso_id') ?? '';
      _idosoId = activeIdosoId;

      if (activeIdosoId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(activeIdosoId)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _idosoNome = data['nome'] as String? ?? 'Meu Idoso';
          _idosoFoto = data['fotoUrl'] as String? ?? data['foto'] as String?;
          
          final lastSeen = data['lastSeen'];
          if (lastSeen != null) {
            DateTime? dt;
            if (lastSeen is Timestamp) dt = lastSeen.toDate();
            if (lastSeen is String) dt = DateTime.tryParse(lastSeen);
            if (dt != null) {
              _isOnline = DateTime.now().difference(dt).inMinutes < 5;
            }
          }
        }
      }
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
          const SnackBar(
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
        final msg = VideoCallService.instance.lastStartFailureMessage ??
            'Não foi possível conectar a chamada agora.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
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
                      border: Border.all(color: AppColors.outlineVariant, width: 2),
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
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColors.primaryContainer,
                              backgroundImage: _idosoFoto != null && _idosoFoto!.startsWith('http')
                                  ? NetworkImage(_idosoFoto!) as ImageProvider
                                  : null,
                              child: _idosoFoto == null || !_idosoFoto!.startsWith('http')
                                  ? Text(
                                      _idosoNome.isNotEmpty ? _idosoNome[0].toUpperCase() : 'I',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _idosoNome,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOnline ? '🟢 Online e Conectado' : '⚪ Visto recentemente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isOnline ? Colors.green.shade700 : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // BOTÕES DE LIGAÇÃO
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCalling ? null : () => _iniciarChamada('video'),
                                icon: const Icon(Icons.videocam, size: 28),
                                label: const Text(
                                  'Vídeo',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCalling ? null : () => _iniciarChamada('voice'),
                                icon: const Icon(Icons.phone, size: 28),
                                label: const Text(
                                  'Voz',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00695C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        children: const [
                          MissedCallsBadge(
                            child: Icon(Icons.history, color: AppColors.primary, size: 26),
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
                          stream: VideoCallService.instance.watchCallHistory(_idosoId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
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
                                child: const Text(
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
                                final isMissed = call.status == VideoCallStatus.missed;
                                final isVoice = call.callType == 'voice';
                                final dateStr = call.startedAt != null
                                    ? '${call.startedAt!.day.toString().padLeft(2, '0')}/${call.startedAt!.month.toString().padLeft(2, '0')} às ${call.startedAt!.hour.toString().padLeft(2, '0')}:${call.startedAt!.minute.toString().padLeft(2, '0')}'
                                    : '';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 1,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isMissed
                                          ? AppColors.errorContainer
                                          : AppColors.primaryContainer,
                                      child: Icon(
                                        isMissed
                                            ? Icons.phone_missed
                                            : (isVoice ? Icons.phone : Icons.videocam),
                                        color: isMissed ? AppColors.error : AppColors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      isVoice ? 'Chamada de Voz' : 'Chamada de Vídeo',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      isMissed ? 'Chamada Perdida • $dateStr' : 'Concluída • $dateStr',
                                      style: TextStyle(
                                        color: isMissed ? AppColors.error : AppColors.onSurfaceVariant,
                                        fontWeight: isMissed ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.call, color: AppColors.primary),
                                      onPressed: () => _iniciarChamada(call.callType),
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
