import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/lembrete_service.dart';
import '../models/lembrete.dart';

class SupervisorReminderDetailScreen extends StatelessWidget {
  final String title;
  final String time;
  final IconData iconData;
  final Color accentColor;
  final String category;
  final Lembrete? lembrete;

  const SupervisorReminderDetailScreen({
    super.key,
    required this.title,
    required this.time,
    required this.iconData,
    required this.accentColor,
    required this.category,
    this.lembrete,
  });

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir Lembrete?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 24),
        ),
        content: Text(
          'Tem certeza que deseja excluir o lembrete "$title"?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (lembrete != null) {
                try {
                  await LembreteService.instance.remover(lembrete!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lembrete excluído com sucesso!'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao excluir: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openBulaAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _BulaAssistantModal(
          medicationName: title,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMedication = category.toLowerCase() == 'medicamento' || category.toLowerCase() == 'medicacao';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, size: 56, color: accentColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule, size: 24, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.05,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 64,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/new-reminder',
                                arguments: lembrete,
                              ),
                              icon: const Icon(Icons.edit, size: 24),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'EDITAR',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        if (lembrete != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmarExclusao(context),
                                icon: const Icon(Icons.delete, size: 24),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'EXCLUIR',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isMedication) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: OutlinedButton.icon(
                          onPressed: () => _openBulaAssistant(context),
                          icon: const Icon(Icons.auto_awesome, size: 28),
                          label: const Text(
                            'PERGUNTAR À BULA (IA)',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 2.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: accentColor, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Detalhes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: accentColor),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BulaAssistantModal extends StatefulWidget {
  final String medicationName;
  final ScrollController scrollController;

  const _BulaAssistantModal({
    required this.medicationName,
    required this.scrollController,
  });

  @override
  State<_BulaAssistantModal> createState() => _BulaAssistantModalState();
}

class _BulaAssistantModalState extends State<_BulaAssistantModal> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'ia',
      'text': 'Olá! Sou o Assistente de Bula Digital. Qual sua dúvida sobre o medicamento **${widget.medicationName}**?',
    });
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || _loading) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _loading = true;
    });
    _inputController.clear();

    try {
      final answer = await LembreteService.instance.queryMedicationFAQ(
        medicationName: widget.medicationName,
        question: text,
      );
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'ia', 'text': answer});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ia',
            'text': 'Erro ao conectar à IA. Por favor, tente novamente.',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickQuestions = [
      'Como tomar?',
      'Esqueci a dose. O que fazer?',
      'Efeitos colaterais comuns?',
      'Dá sono?',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bula Inteligente - ${widget.medicationName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isIA = msg['sender'] == 'ia';
                return Align(
                  alignment: isIA ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isIA ? AppColors.surfaceContainerHigh : AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isIA ? Radius.zero : const Radius.circular(12),
                        bottomRight: isIA ? const Radius.circular(12) : Radius.zero,
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isIA ? AppColors.onSurface : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_loading && _messages.length == 1)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: quickQuestions.length,
                itemBuilder: (context, idx) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(quickQuestions[idx]),
                    onPressed: () => _sendMessage(quickQuestions[idx]),
                    backgroundColor: AppColors.surfaceContainerLow,
                    labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Pergunte sobre o remédio...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => _sendMessage(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
