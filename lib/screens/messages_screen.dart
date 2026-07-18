import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/app_message.dart';
import '../services/message_service.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _sending = false;
  bool _isLoadingRole = true;
  String? _fotoIdoso;
  String? _fotoSupervisor;
  String? _nomeSupervisor;
  final TextEditingController _textController = TextEditingController();

  // Voice recording state
  final AudioRecorder _voiceRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool get _isSupervisor => SessionRoleService.isSupervisor;

  String? _profilePhotoUrl(Map<String, dynamic> data) {
    final photo = (data['fotoPath'] as String?) ?? (data['foto'] as String?);
    if (photo == null || photo.isEmpty || !photo.startsWith('http')) {
      return null;
    }
    return photo;
  }

  Future<Map<String, dynamic>?> _loadSupervisorData(
    String idosoId,
    Map<String, dynamic>? localProfile,
  ) async {
    String? supervisorId = localProfile?['supervisorId'] as String?;

    if (Firebase.apps.isNotEmpty) {
      final perfilDoc = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .get();
      if (perfilDoc.exists && perfilDoc.data() != null) {
        supervisorId =
            perfilDoc.data()!['supervisorId'] as String? ?? supervisorId;
      }
      if (supervisorId == null || supervisorId.isEmpty) {
        final idosoDoc = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();
        if (idosoDoc.exists && idosoDoc.data() != null) {
          supervisorId =
              idosoDoc.data()!['supervisorId'] as String? ?? supervisorId;
        }
      }

      if (supervisorId != null && supervisorId.isNotEmpty) {
        final supervisorDoc = await FirebaseFirestore.instance
            .collection('supervisores')
            .doc(supervisorId)
            .get();
        if (supervisorDoc.exists && supervisorDoc.data() != null) {
          return supervisorDoc.data()!;
        }
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSessionAndMessages();
  }

  Future<void> _loadSessionAndMessages() async {
    await SessionRoleService.load();
    await MessageService.instance.load();

    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();
      _nomeSupervisor = prefs.getString('caregiver_name');
      Map<String, dynamic>? localProfile;
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          localProfile = Map<String, dynamic>.from(decoded);
        }
      }

      bool loadedFromFirebase = false;
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              _fotoIdoso = _profilePhotoUrl(data);
              _fotoSupervisor = null;
            });
          }
          loadedFromFirebase = true;
        }
      }

      final supervisorData = await _loadSupervisorData(idosoId, localProfile);
      if (supervisorData != null && mounted) {
        final supervisorName = supervisorData['nome'] as String?;
        if (supervisorName != null && supervisorName.isNotEmpty) {
          await prefs.setString('caregiver_name', supervisorName);
        }
        setState(() {
          _fotoSupervisor = _profilePhotoUrl(supervisorData);
          _nomeSupervisor = supervisorName ?? _nomeSupervisor;
        });
      }

      if (!loadedFromFirebase) {
        if (localProfile != null && mounted) {
          setState(() {
            _fotoIdoso = _profilePhotoUrl(localProfile!);
            _fotoSupervisor ??=
                _profilePhotoUrl({'fotoPath': localProfile!['fotoSupervisor']});
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar fotos do chat: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingRole = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordingTimer?.cancel();
    _voiceRecorder.isRecording().then((recording) {
      if (recording) {
        _voiceRecorder.stop().then((_) => _voiceRecorder.dispose());
      } else {
        _voiceRecorder.dispose();
      }
    }).catchError((_) {
      try {
        _voiceRecorder.dispose();
      } catch (_) {}
    });
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (await _voiceRecorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/msg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        await _voiceRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        if (!mounted) return;
        setState(() {
          _isRecordingVoice = true;
          _recordingSeconds = 0;
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _recordingSeconds++;
          });
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de microfone negada.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar gravacao: $e');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      await _voiceRecorder.stop();
    } catch (e) {
      debugPrint('Erro ao cancelar gravacao: $e');
    }
    _recordingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (e) {
      debugPrint('Erro ao parar gravacao: $e');
    }
    _recordingTimer?.cancel();
    if (path != null) {
      if (!mounted) return;
      setState(() => _sending = true);
      try {
        final sent = await MessageService.instance.sendAudio(
          audioPath: path,
          fallbackText: 'Mensagem de voz',
          duracaoSegundos: _recordingSeconds,
        );
        if (!sent) {
          throw StateError('Nenhum cuidador conectado para receber a mensagem.');
        }
        if (mounted && !_isSupervisor) {
          TTSService.instance.falar('Mensagem de voz enviada.', caller: this);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível enviar: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isRecordingVoice = false;
            _recordingSeconds = 0;
            _sending = false;
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o áudio. Tente gravar novamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final sent = await MessageService.instance.sendText(text);
      if (!sent) {
        throw StateError('Nenhum cuidador conectado para receber a mensagem.');
      }
      _textController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _confirmDeleteMessage(AppMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Excluir Recado',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008069)),
          ),
          content: const Text(
            'Deseja realmente apagar este recado para ambos?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Color(0xFF008069), fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await MessageService.instance.deleteMessage(message.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recado excluído com sucesso.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao excluir recado. Verifique sua conexão.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'EXCLUIR',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFEAE2),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF008069)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2),
      floatingActionButton: !_isSupervisor
          ? const AlexFloatingHelpButton(
              textoExplicacao:
                  'Olá! Esta é a tela de mensagens. Aqui você pode ler ou ouvir os recados do seu cuidador, digitar mensagens ou mandar áudios segurando o microfone.',
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(),
            Expanded(
              child: ValueListenableBuilder<List<AppMessage>>(
                valueListenable: MessageService.instance.notifier,
                builder: (context, messages, _) {
                  if (messages.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemBuilder: (context, index) =>
                        _messageBubble(messages[index]),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemCount: messages.length,
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final contactName = _isSupervisor ? 'Idoso' : (_nomeSupervisor ?? 'Cuidador');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF008069),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 20,
            backgroundImage: _isSupervisor
                ? (_fotoIdoso != null && _fotoIdoso!.isNotEmpty ? NetworkImage(_fotoIdoso!) : null)
                : (_fotoSupervisor != null && _fotoSupervisor!.isNotEmpty ? NetworkImage(_fotoSupervisor!) : null),
            child: (_isSupervisor
                    ? _fotoIdoso == null || _fotoIdoso!.isEmpty
                    : _fotoSupervisor == null || _fotoSupervisor!.isEmpty)
                ? Icon(
                    _isSupervisor ? Icons.elderly : Icons.person,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contactName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'online',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.mark_chat_unread_outlined,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhum recado ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF008069),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'As mensagens de texto e áudio aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(AppMessage message) {
    final sentByMe = _isSupervisor
        ? message.senderRole == 'supervisor'
        : message.senderRole == 'elderly';

    final bubbleColor = sentByMe
        ? const Color(0xFFE7FFDB) // WhatsApp green sent bubble
        : Colors.white; // WhatsApp white received bubble

    final alignment = sentByMe ? Alignment.centerRight : Alignment.centerLeft;
    final time =
        '${message.criadoEm.hour.toString().padLeft(2, '0')}:${message.criadoEm.minute.toString().padLeft(2, '0')}';

    // Custom font size for elderly readability
    final double textFontSize = _isSupervisor ? 16.0 : 20.0;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: () => _confirmDeleteMessage(message),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: sentByMe ? const Radius.circular(12) : const Radius.circular(0),
              bottomRight: sentByMe ? const Radius.circular(0) : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 1,
                offset: const Offset(0, 1),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.tipo == 'audio' && message.audioPath != null)
                AudioPlayerCard(
                  key: ValueKey(message.id),
                  audioPath: message.audioPath,
                  subtitle: '',
                  isChatDesign: true,
                  accentColor: const Color(0xFF008069),
                  defaultDuration: Duration(seconds: message.duracaoSegundos ?? 0),
                )
              else if (message.tipo == 'localizacao' && message.audioPath != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            message.texto,
                            style: TextStyle(
                              fontSize: textFontSize,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF008069), size: 24),
                          onPressed: () => TTSService.instance.falar(message.texto, caller: this),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final Uri uri = Uri.parse(message.audioPath!);
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Erro ao abrir maps: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text(
                        'ABRIR NO GOOGLE MAPS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        message.texto,
                        style: TextStyle(
                          fontSize: textFontSize,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Color(0xFF008069), size: 24),
                      onPressed: () => TTSService.instance.falar(message.texto, caller: this),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (sentByMe) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: _isRecordingVoice ? _buildVoiceRecordingComposer() : _buildStandardComposer(),
    );
  }

  Widget _buildVoiceRecordingComposer() {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            'Gravando: $minutes:$seconds',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 26),
            onPressed: _cancelVoiceRecording,
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF008069),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 22),
              onPressed: _stopAndSendVoiceRecording,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardComposer() {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton.icon(
        onPressed: _sending ? null : _startVoiceRecording,
        icon: const Icon(Icons.mic, size: 32, color: Colors.white),
        label: const Text(
          'GRAVAR RECADO DE VOZ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF008069),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
