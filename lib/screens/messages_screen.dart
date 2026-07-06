import 'dart:async';

import 'package:flutter/material.dart';
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

  // Voice recording state
  final AudioRecorder _voiceRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool get _isSupervisor => SessionRoleService.isSupervisor;

  @override
  void initState() {
    super.initState();
    _loadSessionAndMessages();
  }

  Future<void> _loadSessionAndMessages() async {
    await SessionRoleService.load();
    await MessageService.instance.load();
    if (mounted) {
      setState(() {
        _isLoadingRole = false;
      });
    }
  }

  @override
  void dispose() {
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
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/msg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    await _voiceRecorder.stop();
    _recordingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    final path = await _voiceRecorder.stop();
    _recordingTimer?.cancel();
    if (path != null) {
      if (!mounted) return;
      setState(() => _sending = true);
      try {
        await MessageService.instance.sendAudio(
          audioPath: path,
          fallbackText: 'Mensagem de voz',
        );
        if (mounted && !_isSupervisor) {
          TTSService.instance.falar('Mensagem de voz enviada.', caller: this);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: null, // Always null for both supervisor and elderly
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    itemBuilder: (context, index) =>
                        _messageBubble(messages[index]),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isSupervisor ? 'Recados do idoso' : 'Recados do cuidador',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (!_isSupervisor) ...[
                const SizedBox(height: 6),
                const MeExplicaButton(
                  textoExplicacao:
                      'Olá! Esta é a tela de recados. Aqui você pode escutar os recados do seu cuidador e responder enviando recados de voz tocando no botão gigante de gravar.',
                ),
              ],
            ],
          ),
          const Spacer(),
          const SizedBox(width: 48), // Mantém o equilíbrio visual com o botão de voltar no lado oposto
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
              color: AppColors.outline,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhum recado ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'As mensagens de texto e áudio aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: AppColors.onSurfaceVariant),
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
        ? AppColors.secondaryContainer
        : AppColors.surfaceContainerLowest;
    final borderColor = sentByMe
        ? AppColors.secondary
        : AppColors.outlineVariant;
    final alignment = sentByMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final time =
        '${message.criadoEm.hour.toString().padLeft(2, '0')}:${message.criadoEm.minute.toString().padLeft(2, '0')}';
    
    // Scale text and bubbles for elderly
    final double textFontSize = _isSupervisor ? 18.0 : 22.0;

    return Align(
      alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.senderRole == 'supervisor'
                        ? Icons.health_and_safety
                        : Icons.elderly,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.senderRole == 'supervisor'
                        ? 'Cuidador'
                        : message.nomeIdoso,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (message.tipo == 'audio' && message.audioPath != null)
                AudioPlayerCard(
                  audioPath: message.audioPath,
                  subtitle: message.texto,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        message.texto,
                        style: TextStyle(
                          fontSize: textFontSize,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
                      onPressed: () => TTSService.instance.falar(message.texto, caller: this),
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: _isRecordingVoice ? _buildVoiceRecordingComposer() : _buildStandardComposer(),
    );
  }

  Widget _buildVoiceRecordingComposer() {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Gravando: $minutes:$seconds',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _cancelVoiceRecording,
                  icon: const Icon(Icons.delete, size: 28),
                  label: const Text(
                    'APAGAR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _stopAndSendVoiceRecording,
                  icon: const Icon(Icons.send, size: 28),
                  label: const Text(
                    'ENVIAR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
