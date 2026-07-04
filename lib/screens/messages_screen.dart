import 'package:flutter/material.dart';

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
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  bool get _isSupervisor => SessionRoleService.isSupervisor;

  @override
  void initState() {
    super.initState();
    MessageService.instance.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MessageService.instance.sendText(text);
      _controller.clear();
      if (!_isSupervisor) {
        TTSService.instance.falar(
          'Recado enviado para o seu cuidador.',
          caller: this,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _isSupervisor
          ? const SupervisorBottomNav(selected: SupervisorNavDestination.help)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ValueListenableBuilder<List<AppMessage>>(
                valueListenable: MessageService.instance.notifier,
                builder: (context, messages, _) {
                  if (messages.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.forum, color: AppColors.primary, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isSupervisor ? 'Recados do idoso' : 'Recados do cuidador',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (!_isSupervisor) ...[
                  const SizedBox(height: 6),
                  const MeExplicaButton(
                    textoExplicacao:
                        'Olá! Esta é a tela de recados. Aqui você pode ler as mensagens enviadas pelo seu cuidador e também mandar mensagens para ele tocando no campo de texto na parte inferior ou usando o botão de gravar áudio.',
                  ),
                ],
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
                Text(
                  message.texto,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: _isSupervisor
                    ? 'Responder ao idoso'
                    : 'Escrever um recado',
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            width: 56,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendText,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
