import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../services/lembrete_service.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../utils/audio_path_helper.dart';
import '../utils/app_image_helper.dart';

class SupervisorReminderDetailScreen extends StatefulWidget {
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

  @override
  State<SupervisorReminderDetailScreen> createState() =>
      _SupervisorReminderDetailScreenState();
}

class _SupervisorReminderDetailScreenState
    extends State<SupervisorReminderDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final path = widget.lembrete?.audioPath;
    if (path == null || path.isEmpty) return;

    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlayingAudio = false);
    } else {
      try {
        await _audioPlayer.play(audioSourceForPath(path));
      } catch (e) {
        debugPrint('Erro ao reproduzir áudio da família: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível reproduzir o áudio gravado.'),
            ),
          );
        }
      }
    }
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir Lembrete?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.error,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Tem certeza que deseja excluir o lembrete "${widget.title}"? O idoso deixará de ser notificado neste horário.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.lembrete != null) {
                try {
                  await LembreteService.instance.remover(widget.lembrete!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Excluir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getRecorrenciaTexto(Lembrete l) {
    if (l.recorrencia == 'unico' || l.lembreteUnico) {
      return 'Lembrete único';
    } else if (l.recorrencia == 'semanal' || l.recorrenciaSemanal) {
      const diaNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      final dias = l.diasSemana
          .map((d) => d >= 1 && d <= 7 ? diaNomes[d - 1] : '')
          .where((s) => s.isNotEmpty)
          .join(', ');
      return dias.isNotEmpty ? 'Semanal: $dias' : 'Semanal';
    } else if (l.recorrencia == 'mensal' || l.recorrenciaMensal) {
      return 'Mensal (dia ${l.diaMes ?? l.criadoEm.day})';
    } else if (l.recorrencia == 'intervalo' || l.recorrenciaIntervalo) {
      return 'A cada ${l.intervaloHoras ?? 8} horas';
    } else {
      return 'Todos os dias';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMedication =
        widget.category.toLowerCase() == 'medicamento' ||
        widget.category.toLowerCase() == 'medicacao';
    final tabCount = isMedication ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: widget.accentColor, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Detalhes do Lembrete',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: widget.accentColor,
            ),
          ),
          actions: [
            if (widget.lembrete != null) ...[
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                tooltip: 'Editar Lembrete',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/new-reminder',
                  arguments: widget.lembrete,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 26,
                ),
                tooltip: 'Excluir Lembrete',
                onPressed: () => _confirmarExclusao(context),
              ),
              const SizedBox(width: 8),
            ],
          ],
          bottom: TabBar(
            labelColor: widget.accentColor,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: widget.accentColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              const Tab(
                text: 'DETALHES',
                icon: Icon(Icons.info_outline_rounded),
              ),
              const Tab(text: 'HISTÓRICO', icon: Icon(Icons.history_rounded)),
              if (isMedication)
                const Tab(
                  text: 'BULA (IA)',
                  icon: Icon(Icons.auto_awesome_rounded),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Aba 1: Detalhes
            _buildDetailsTab(),

            // Aba 2: Histórico de Adesão
            _buildHistoryTab(),

            // Aba 3: Bula Inteligente (se medicação)
            if (isMedication)
              _BulaAssistantTabContent(medicationName: widget.title),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final photoPath = widget.lembrete?.medicamentoFotoPath;
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final hasInstructions =
        widget.lembrete?.medicamentoInstrucoes != null &&
        widget.lembrete!.medicamentoInstrucoes!.isNotEmpty;
    final hasAudio =
        widget.lembrete?.audioPath != null &&
        widget.lembrete!.audioPath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Principal: Resumo Visual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPhotoOrIcon(hasPhoto, photoPath),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.time,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    widget.category,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card de Frequência e Recorrência
          if (widget.lembrete != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Frequência do Lembrete',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getRecorrenciaTexto(widget.lembrete!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (widget.lembrete?.dataInicio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Início: ${widget.lembrete!.dataInicio!.day.toString().padLeft(2, '0')}/${widget.lembrete!.dataInicio!.month.toString().padLeft(2, '0')}/${widget.lembrete!.dataInicio!.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (widget.lembrete?.isUsoContinuo == false &&
                      widget.lembrete?.dataFim != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fim: ${widget.lembrete!.dataFim!.day.toString().padLeft(2, '0')}/${widget.lembrete!.dataFim!.month.toString().padLeft(2, '0')}/${widget.lembrete!.dataFim!.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Card de Orientações / Instruções
          if (hasInstructions) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Instruções ao Idoso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.lembrete!.medicamentoInstrucoes!,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Card de Reprodutor de Áudio Gravado
          if (hasAudio) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mic_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Áudio Personalizado da Família',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Este é o áudio gravado que o idoso escuta ao ser notificado.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _isPlayingAudio
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                      ),
                      label: Text(
                        _isPlayingAudio
                            ? 'PARAR ÁUDIO'
                            : 'OUVIR GRAVAÇÃO DA FAMÍLIA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlayingAudio
                            ? AppColors.error
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Ações Rápidas no final
          if (widget.lembrete != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/new-reminder',
                      arguments: widget.lembrete,
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'EDITAR LEMBRETE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (widget.lembrete == null) {
      return Center(
        child: Text(
          'Lembrete ainda não salvo para exibir histórico.',
          style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return ValueListenableBuilder<List<LembreteEvento>>(
      valueListenable: LembreteService.instance.eventosNotifier,
      builder: (context, todosEventos, child) {
        final eventos =
            todosEventos
                .where((e) => e.lembreteId == widget.lembrete!.id)
                .toList()
              ..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));

        final total = eventos.length;
        final concluidos = eventos.where((e) => e.status.isConcluido).length;
        final perdidos = eventos
            .where((e) => e.status == LembreteStatus.perdido)
            .length;
        final taxa = total > 0 ? ((concluidos / total) * 100).round() : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Resumo de Adesão
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Resumo de Adesão do Lembrete',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Taxa', '$taxa%', AppColors.primary),
                        _buildStatItem(
                          'Concluídos',
                          '$concluidos',
                          AppColors.success,
                        ),
                        _buildStatItem(
                          'Perdidos',
                          '$perdidos',
                          AppColors.error,
                        ),
                        _buildStatItem(
                          'Total Logs',
                          '$total',
                          AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Histórico Cronológico',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              if (eventos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AppColors.outline,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Nenhum registro de atividade para este lembrete ainda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final evento = eventos[index];
                    Color statusColor;
                    IconData statusIcon;
                    String statusText;

                    if (evento.status.isConcluido) {
                      statusColor = AppColors.success;
                      statusIcon = Icons.check_circle_rounded;
                      statusText = 'Concluído';
                    } else if (evento.status == LembreteStatus.adiado) {
                      statusColor = AppColors.warning;
                      statusIcon = Icons.update_rounded;
                      statusText = 'Adiado';
                    } else if (evento.status == LembreteStatus.perdido) {
                      statusColor = AppColors.error;
                      statusIcon = Icons.cancel_rounded;
                      statusText = 'Não Respondido / Perdido';
                    } else if (evento.status == LembreteStatus.precisaDeAjuda) {
                      statusColor = AppColors.error;
                      statusIcon = Icons.sos_rounded;
                      statusText = 'Pediu Ajuda';
                    } else {
                      statusColor = AppColors.primary;
                      statusIcon = Icons.info_rounded;
                      statusText = 'Registrado';
                    }

                    final d = evento.registradoEm;
                    final dataStr =
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dataStr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                if (evento.observacao != null &&
                                    evento.observacao!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    evento.observacao!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoOrIcon(bool hasPhoto, String? photoPath) {
    if (!hasPhoto || photoPath == null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.iconData, size: 56, color: widget.accentColor),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image(
                      image: photoPath.startsWith('assets/')
                          ? AssetImage(photoPath) as ImageProvider
                          : (kIsWeb || photoPath.startsWith('http'))
                          ? NetworkImage(photoPath) as ImageProvider
                          : AppImageHelper.resizedFileImage(
                              File(photoPath),
                              maxWidth: 1200,
                              maxHeight: 1200,
                            ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: widget.accentColor, width: 4),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: Image(
            image: photoPath.startsWith('assets/')
                ? AssetImage(photoPath) as ImageProvider
                : (kIsWeb || photoPath.startsWith('http'))
                ? NetworkImage(photoPath) as ImageProvider
                : AppImageHelper.resizedFileImage(
                    File(photoPath),
                    maxWidth: 400,
                    maxHeight: 400,
                  ),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(widget.iconData, size: 56, color: widget.accentColor),
          ),
        ),
      ),
    );
  }
}

class _BulaAssistantTabContent extends StatefulWidget {
  final String medicationName;

  const _BulaAssistantTabContent({required this.medicationName});

  @override
  State<_BulaAssistantTabContent> createState() =>
      _BulaAssistantTabContentState();
}

class _BulaAssistantTabContentState extends State<_BulaAssistantTabContent> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'ia',
      'text':
          'Olá! Sou o Assistente de Bula Digital. Qual sua dúvida sobre o medicamento **${widget.medicationName}**?',
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || _loading) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _loading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final answer = await LembreteService.instance.queryMedicationFAQ(
        medicationName: widget.medicationName,
        question: text,
      );
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'ia', 'text': answer});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ia',
            'text': 'Erro ao conectar à IA. Por favor, tente novamente.',
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quickQuestions = [
      'Como tomar?',
      'Esqueci a dose. O que fazer?',
      'Efeitos colaterais comuns?',
      'Dá sono?',
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bula Inteligente - ${widget.medicationName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isIA = msg['sender'] == 'ia';
              return Align(
                alignment: isIA ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: isIA
                        ? AppColors.surfaceContainerHigh
                        : AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isIA
                          ? Radius.zero
                          : const Radius.circular(16),
                      bottomRight: isIA
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                  ),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(
                      fontSize: 15,
                      color: isIA ? AppColors.onSurface : Colors.white,
                      height: 1.35,
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
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
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
                      borderRadius: BorderRadius.circular(16),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () => _sendMessage(_inputController.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
