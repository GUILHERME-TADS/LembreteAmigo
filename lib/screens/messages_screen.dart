import 'dart:async';
import 'dart:convert';

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
import '../services/offline_sync_service.dart';
import '../services/presence_service.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/secure_cache_service.dart';
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
  bool _isStartingRecording = false;
  final Set<String> _deletingMessageIds = <String>{};
  String? _deleteDialogMessageId;
  bool _isLoadingRole = true;
  String? _fotoIdoso;
  String? _fotoSupervisor;
  String? _nomeSupervisor;
  String? _nomeIdoso;
  String? _targetUserId;
  final TextEditingController _textController = TextEditingController();

  // Voice recording state
  final AudioRecorder _voiceRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool get _isSupervisor => SessionRoleService.isSupervisor;

  String? _profilePhotoUrl(Map<String, dynamic> data) {
    final photo = (data['fotoPath'] as String?) ?? (data['foto'] as String?);
    if (photo == null || photo.isEmpty) {
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
      final profile = await ElderlyProfileRepository.instance.getData(idosoId);
      supervisorId = profile?['supervisorId'] as String? ?? supervisorId;

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
    MessageService.instance.notifier.addListener(_markIncomingMessagesRead);
    _loadSessionAndMessages();
  }

  void _markIncomingMessagesRead() {
    unawaited(MessageService.instance.markIncomingMessagesRead());
  }

  Future<void> _loadSessionAndMessages() async {
    await SessionRoleService.load();
    await MessageService.instance.load();
    await MessageService.instance.markIncomingMessagesRead();

    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();
      _nomeSupervisor = prefs.getString('caregiver_name');
      Map<String, dynamic>? localProfile;
      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          localProfile = Map<String, dynamic>.from(decoded);
          if (mounted) {
            setState(() {
              _nomeIdoso = localProfile?['nome'] as String?;
            });
          }
        }
      }

      String? localFoto = prefs.getString('idoso_foto_path');
      if (localFoto != null && localFoto.isEmpty) localFoto = null;

      bool loadedFromFirebase = false;
      if (Firebase.apps.isNotEmpty) {
        final data = await ElderlyProfileRepository.instance.getData(idosoId);
        if (data != null) {
          if (mounted) {
            setState(() {
              _fotoIdoso = _profilePhotoUrl(data) ?? localFoto;
              _nomeIdoso = data['nome'] as String? ?? _nomeIdoso;
              _fotoSupervisor = null;
            });
          }
          loadedFromFirebase = true;
        }
      }

      if (!loadedFromFirebase && mounted) {
        setState(() {
          _fotoIdoso = localFoto;
        });
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
        final cachedProfile = localProfile;
        if (cachedProfile != null && mounted) {
          setState(() {
            _fotoIdoso ??= _profilePhotoUrl(cachedProfile) ?? localFoto;
            _fotoSupervisor ??= _profilePhotoUrl({
              'fotoPath': cachedProfile['fotoSupervisor'],
            });
          });
        }
      }
      if (_isSupervisor) {
        _targetUserId = idosoId;
      } else {
        _targetUserId =
            (supervisorData?['uid'] as String?) ??
            (localProfile?['supervisorId'] as String?);
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
    MessageService.instance.notifier.removeListener(_markIncomingMessagesRead);
    _textController.dispose();
    _recordingTimer?.cancel();
    _voiceRecorder
        .isRecording()
        .then((recording) {
          if (recording) {
            _voiceRecorder.stop().then((_) => _voiceRecorder.dispose());
          } else {
            _voiceRecorder.dispose();
          }
        })
        .catchError((_) {
          try {
            _voiceRecorder.dispose();
          } catch (_) {}
        });
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (_sending || _isStartingRecording || _isRecordingVoice) return;
    await TTSService.instance.parar();
    setState(() => _isStartingRecording = true);
    try {
      if (await _voiceRecorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path =
              '${tempDir.path}/msg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        await _voiceRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            autoGain: true,
            echoCancel: true,
            noiseSuppress: true,
          ),
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
          SnackBar(
            content: Text(
              'Não consegui usar o microfone. Se o celular pedir, aperte Permitir.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar gravacao: $e');
    } finally {
      if (mounted) setState(() => _isStartingRecording = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (_sending) return;
    setState(() => _sending = true);
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
      _sending = false;
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    if (_sending) return;
    setState(() => _sending = true);
    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (e) {
      debugPrint('Erro ao parar gravacao: $e');
    }
    _recordingTimer?.cancel();
    if (path != null) {
      if (!mounted) return;
      try {
        final sent = await MessageService.instance.sendAudio(
          audioPath: path,
          fallbackText: 'Mensagem de voz',
          duracaoSegundos: _recordingSeconds,
        );
        if (!sent) {
          throw StateError(
            'Nenhum cuidador conectado para receber a mensagem.',
          );
        }
        if (mounted && !_isSupervisor) {
          TTSService.instance.falar('Recado de voz enviado.', caller: this);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não consegui enviar. Tente de novo.'),
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
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não consegui guardar o recado. Grave de novo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmDeleteMessage(AppMessage message) {
    if (_deleteDialogMessageId != null) return;
    _deleteDialogMessageId = message.id;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Apagar Recado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          content: const Text(
            'Apagar este recado do seu celular e do celular do cuidador?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCELAR',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_deletingMessageIds.contains(message.id)) return;
                _deletingMessageIds.add(message.id);
                Navigator.pop(context);
                try {
                  await MessageService.instance.deleteMessage(message.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recado apagado.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Não consegui apagar. Veja se a internet está ligada.',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } finally {
                  _deletingMessageIds.remove(message.id);
                }
              },
              child: Text(
                'APAGAR',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _deleteDialogMessageId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: !_isSupervisor
          ? const AlexFloatingHelpButton(
              textoExplicacao:
                  'Olá! Esta é a tela de recados. Aqui você pode ler ou ouvir os recados do seu cuidador. Para responder, aperte o microfone e grave um recado de voz.',
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!_isSupervisor) const VolumeWarningBanner(),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
    final contactName = _isSupervisor
        ? (_nomeIdoso ?? 'Idoso')
        : (_nomeSupervisor ?? 'Cuidador');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
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
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              ElderlyProfileAvatar(
                fotoPath: _isSupervisor ? _fotoIdoso : _fotoSupervisor,
                size: 40,
                borderWidth: 0,
              ),
              StreamBuilder<PresenceStatus>(
                stream: PresenceService.instance.watchUserPresence(
                  userId: _targetUserId ?? '',
                  isSupervisorTarget: !_isSupervisor,
                ),
                builder: (context, snapshot) {
                  final isOnline = snapshot.data?.isOnline ?? false;
                  if (!isOnline) return const SizedBox.shrink();
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ],
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
                StreamBuilder<PresenceStatus>(
                  stream: PresenceService.instance.watchUserPresence(
                    userId: _targetUserId ?? '',
                    isSupervisorTarget: !_isSupervisor,
                  ),
                  builder: (context, snapshot) {
                    final presence = snapshot.data;
                    final text = presence?.statusText ?? 'Offline';
                    final isOnline = presence?.isOnline ?? false;
                    return Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isOnline
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isOnline
                            ? AppColors.successContainer
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    );
                  },
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
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 72, color: AppColors.outline),
            SizedBox(height: 16),
            Text(
              'Nenhum recado ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Os recados escritos e falados aparecem aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.outline),
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

    final Color bubbleColor = sentByMe
        ? AppColors.primaryContainer
        : AppColors.surfaceContainerLow;
    final textColor = sentByMe
        ? AppColors.onPrimaryContainer
        : AppColors.onSurface;

    final alignment = sentByMe ? Alignment.centerRight : Alignment.centerLeft;
    final time =
        '${message.criadoEm.hour.toString().padLeft(2, '0')}:${message.criadoEm.minute.toString().padLeft(2, '0')}';

    // Custom font size for elderly readability
    final double textFontSize = _isSupervisor ? 16.0 : 20.0;

    final Widget bubbleWidget = GestureDetector(
      onLongPress: () => _confirmDeleteMessage(message),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: sentByMe
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: sentByMe
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          border: Border.all(
            color: sentByMe
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.outlineVariant,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.tipo == 'audio' && message.audioPath != null) ...[
              AudioPlayerCard(
                key: ValueKey(message.id),
                audioPath: message.audioPath,
                subtitle: '',
                isChatDesign: true,
                accentColor: AppColors.primary,
                defaultDuration: Duration(
                  seconds: message.duracaoSegundos ?? 0,
                ),
              ),
              if (message.texto.isNotEmpty &&
                  message.texto != 'Áudio gravado' &&
                  message.texto != 'Mensagem de voz' &&
                  message.texto != 'Gravação de voz') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bubbleColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          message.texto,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]
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
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.play_circle_fill,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        onPressed: () => TTSService.instance.falar(
                          message.texto,
                          caller: this,
                        ),
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
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        debugPrint('Erro ao abrir maps: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
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
                      'ABRIR MAPA',
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
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_fill,
                      color: AppColors.primary,
                      size: 36,
                    ),
                    onPressed: () =>
                        TTSService.instance.falar(message.texto, caller: this),
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
                  style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                ),
                if (sentByMe) ...[
                  const SizedBox(width: 4),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable:
                        OfflineSyncService.instance.pendingMessageIds,
                    builder: (context, pendingIds, child) {
                      final pending = pendingIds.contains(message.id);
                      return Icon(
                        pending ? Icons.schedule : Icons.done_all,
                        size: 16,
                        color: pending ? AppColors.warning : AppColors.info,
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: bubbleWidget,
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: _isRecordingVoice
          ? _buildVoiceRecordingComposer()
          : _buildStandardComposer(),
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
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text(
            'Gravando: $minutes:$seconds',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.error, size: 26),
            onPressed: _sending ? null : _cancelVoiceRecording,
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 22),
              onPressed: _sending ? null : _stopAndSendVoiceRecording,
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
        onPressed: _sending || _isStartingRecording
            ? null
            : _startVoiceRecording,
        icon: const Icon(Icons.mic, size: 32),
        label: const Text(
          'GRAVAR RECADO DE VOZ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
