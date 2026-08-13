import 'package:flutter/material.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';
import '../utils/period_helper.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersScreenState();
}

class _AllRemindersScreenState extends State<AllRemindersScreen> {
  List<Lembrete> _voiceReminders = [];
  String _selectedCategory = 'todos';
  bool _showCompleted = true;
  bool _showOnlyPending = false;
  bool _isLoadingReminders = true;
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    TTSService.instance.init();
    _loadRemindersFromService();
    _loadProfilePhoto();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  void _loadReminders() {
    _voiceReminders = ReminderStateHelper.activeTodaySorted(
      LembreteService.instance.lembretes,
    );
  }

  Future<void> _loadRemindersFromService() async {
    setState(() => _isLoadingReminders = true);
    try {
      await LembreteService.instance.carregar();
    } catch (e) {
      debugPrint('Erro ao carregar lembretes na tela do idoso: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadReminders();
          _isLoadingReminders = false;
        });
      }
    }
  }

  void _onLembretesChanged() {
    if (mounted) {
      setState(() {
        _loadReminders();
      });
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final localFoto = await ElderlyProfileRepository.instance
          .getCachedPhotoPath();
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto no all reminders: $e');
    }
  }

  (IconData, Color, Color) _categoriaIcon(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return (
          Icons.medication,
          AppColors.medicationsColor,
          AppColors.medicationsColor,
        );
      case 'refeicoes':
        return (Icons.restaurant, AppColors.mealsColor, AppColors.mealsColor);
      case 'exercicio':
        return (
          Icons.directions_walk,
          AppColors.tertiaryContainer,
          AppColors.tertiaryContainer,
        );
      case 'hidratacao':
        return (
          Icons.water_drop,
          AppColors.voiceFeedbackBlue,
          AppColors.voiceFeedbackBlue,
        );
      default:
        return (
          Icons.notifications,
          AppColors.customColor,
          AppColors.customColor,
        );
    }
  }

  void _stopAllAudioAndTts() {
    TTSService.instance.parar(caller: this);
    AudioManager.activeIdNotifier.value = null;
  }

  @override
  void dispose() {
    _stopAllAudioAndTts();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'medicacao':
        return AppColors.medicationsColor;
      case 'refeicoes':
        return AppColors.mealsColor;
      case 'exercicio':
        return AppColors.tertiaryContainer;
      case 'hidratacao':
        return AppColors.voiceFeedbackBlue;
      default:
        return AppColors.primary;
    }
  }

  List<Lembrete> _getByPeriod(List<Lembrete> list, String period) {
    return list.where((r) {
      final h = r.horarioHour;
      if (period == 'madrugada') return h >= 0 && h < 6;
      if (period == 'manha') return h >= 6 && h < 12;
      if (period == 'tarde') return h >= 12 && h < 18;
      return h >= 18 && h < 24; // noite
    }).toList();
  }

  Widget _buildPeriodSection(
    String title,
    IconData icon,
    Color color,
    List<Lembrete> list,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();

    final countText = list.length == 1
        ? '1 lembrete'
        : '${list.length} lembretes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 24, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  countText.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...list.map((r) {
          final (icon, iconBg, accentColor) = _categoriaIcon(r.categoria);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.transparent, // Borda cinza clara oculta
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  ReminderWithAudio(
                    icon: icon,
                    iconBg: iconBg,
                    iconColor: Colors.white,
                    accentColor: accentColor,
                    title: r.titulo,
                    time: r.horarioFormatado,
                    audioPath: r.audioPath == 'ia_generated'
                        ? null
                        : r.audioPath,
                    ttsText: r.audioPath == 'ia_generated'
                        ? r.medicamentoAudioTexto
                        : null,
                    status: reminderVisualStatusFromLembrete(r),
                    onTap: () {
                      _stopAllAudioAndTts();
                      Navigator.pushNamed(
                        context,
                        '/reminder-detail',
                        arguments: r,
                      );
                    },
                    onStatusTap: () async {
                      _stopAllAudioAndTts();
                      if (r.categoria == 'medicacao' && !r.concluido) {
                        await Navigator.pushNamed(
                          context,
                          '/take-photo-confirmation',
                          arguments: r.id,
                        );
                        _loadReminders();
                      } else {
                        await LembreteService.instance.alternarConclusao(r.id);
                        _loadReminders();
                      }
                    },
                  ),
                  if (r.medicamentoInstrucoes != null &&
                      r.medicamentoInstrucoes!.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      color: AppColors.outlineVariant,
                      thickness: 2,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Como fazer: ${r.medicamentoInstrucoes}',
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
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _voiceReminders.length;
    final completed = _voiceReminders.where((r) => r.concluido).length;
    final progress = total > 0 ? completed / total : 0.0;
    final isAllDone = total > 0 && completed == total;

    final categories = [
      {'id': 'todos', 'label': 'Todos', 'icon': Icons.grid_view},
      {'id': 'medicacao', 'label': 'Medicação', 'icon': Icons.medication},
      {'id': 'refeicoes', 'label': 'Refeições', 'icon': Icons.restaurant},
      {'id': 'exercicio', 'label': 'Exercício', 'icon': Icons.directions_walk},
      {'id': 'hidratacao', 'label': 'Hidratação', 'icon': Icons.water_drop},
    ];

    final filteredList = _selectedCategory == 'todos'
        ? _voiceReminders
        : _voiceReminders
              .where((r) => r.categoria == _selectedCategory)
              .toList();

    final pending = filteredList.where((r) => !r.concluido).toList();
    final completedList = _showOnlyPending
        ? <Lembrete>[]
        : filteredList.where((r) => r.concluido).toList();
    final audioSummaryList = _showOnlyPending ? pending : filteredList;

    final madrugadaList = _getByPeriod(pending, 'madrugada');
    final manhaList = _getByPeriod(pending, 'manha');
    final tardeList = _getByPeriod(pending, 'tarde');
    final noiteList = _getByPeriod(pending, 'noite');

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta tela mostra todos os seus lembretes de hoje, em ordem de horário.',
        onTapped: _stopAllAudioAndTts,
      ),
      bottomNavigationBar: const ElderlyBottomNav(
        selected: ElderlyNavDestination.reminders,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(context),
            Expanded(
              child: _isLoadingReminders
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seus lembretes do dia',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Separadas pela hora do dia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),

                          // Card de Progresso
                          if (total > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isAllDone
                                      ? [
                                          AppColors.tertiaryContainer,
                                          AppColors.tertiary,
                                        ]
                                      : [
                                          AppColors.primary,
                                          AppColors.primary,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isAllDone
                                            ? Icons.check_circle
                                            : Icons.trending_up,
                                        color: isAllDone
                                            ? AppColors.tertiaryFixed
                                            : AppColors.secondaryContainer,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isAllDone
                                              ? 'Tudo feito! Excelente!'
                                              : 'Seu progresso de hoje',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isAllDone
                                        ? 'Você realizou todos os seus lembretes. Parabéns por se cuidar!'
                                        : 'Você já fez $completed de $total lembretes de hoje. Continue assim!',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: SizedBox(
                                          height: 28,
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.2),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  isAllDone
                                                      ? AppColors
                                                            .tertiaryFixedDim
                                                      : AppColors
                                                            .secondaryContainer,
                                                ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}% COMPLETO  ${progress >= 1.0
                                            ? "🥳 🎉"
                                            : progress >= 0.7
                                            ? "😎"
                                            : progress >= 0.3
                                            ? "🙂"
                                            : "💪"}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          // Option 2 Toggle Button
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Mostrar apenas o que falta',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _showOnlyPending,
                                  onChanged: (val) {
                                    setState(() {
                                      _showOnlyPending = val;
                                    });
                                  },
                                  activeThumbColor: AppColors.primary,
                                ),
                              ],
                            ),
                          ),

                          // Chips de Filtro por Categoria
                          if (_voiceReminders.isNotEmpty)
                            Container(
                              height: 60,
                              margin: const EdgeInsets.only(top: 16, bottom: 8),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final isSelected =
                                      _selectedCategory == cat['id'];
                                  final icon = cat['icon'] as IconData;
                                  final label = cat['label'] as String;
                                  final catColor = _getCategoryColor(
                                    cat['id'] as String,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      iconTheme: IconThemeData(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.onSurfaceVariant,
                                      ),
                                      avatar: Icon(icon, size: 20),
                                      label: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedCategory =
                                                cat['id'] as String;
                                          });
                                        }
                                      },
                                      selectedColor: catColor,
                                      backgroundColor:
                                          AppColors.surfaceContainerHigh,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: isSelected
                                              ? catColor
                                              : AppColors.outlineVariant,
                                          width: 1.5,
                                        ),
                                      ),
                                      showCheckmark: false,
                                    ),
                                  );
                                },
                              ),
                            ),

                          if (audioSummaryList.isNotEmpty)
                            AudioPlayerCard(
                              subtitle: _selectedCategory == 'todos'
                                  ? (_showOnlyPending
                                        ? 'Ouça os lembretes que ainda faltam'
                                        : 'Ouça todos os lembretes de hoje')
                                  : 'Ouça lembretes de ${_selectedCategory == 'medicacao'
                                        ? 'remédio'
                                        : _selectedCategory == 'refeicoes'
                                        ? 'comida'
                                        : _selectedCategory == 'exercicio'
                                        ? 'exercício'
                                        : 'água'}',
                              textsToSpeak: () {
                                final catLabel =
                                    _selectedCategory == 'medicacao'
                                    ? 'lembretes de medicação'
                                    : _selectedCategory == 'refeicoes'
                                    ? 'lembretes de refeição'
                                    : _selectedCategory == 'exercicio'
                                    ? 'lembretes de exercício'
                                    : _selectedCategory == 'hidratacao'
                                    ? 'lembretes de hidratação'
                                    : 'lembretes';
                                final audioListDone =
                                    audioSummaryList.isNotEmpty &&
                                    audioSummaryList.every((l) => l.concluido);
                                final introText = audioSummaryList.isEmpty
                                    ? 'Você não tem lembretes desta categoria.'
                                    : audioListDone
                                    ? 'Muito bem! Você já fez todos os seus $catLabel de hoje!'
                                    : 'Aqui estão seus $catLabel de hoje:';
                                return [
                                  introText,
                                  ...audioSummaryList.map((l) {
                                    final statusSuffix = l.concluido
                                        ? ' já está pronto.'
                                        : l.status == LembreteStatus.adiado
                                        ? ' ficou para mais tarde.'
                                        : '';
                                    return '${l.titulo} ${PeriodHelper.getSpokenTimeWithPreposition(l.horarioHour, l.horarioMinute)}$statusSuffix';
                                  }),
                                ];
                              }(),
                            ),

                          // Listas por Período (Pendentes)
                          if (pending.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildPeriodSection(
                              'Madrugada',
                              Icons.nightlight_round,
                              AppColors.onSurfaceVariant,
                              madrugadaList,
                            ),
                            _buildPeriodSection(
                              'Manhã',
                              Icons.wb_sunny,
                              AppColors.warning,
                              manhaList,
                            ),
                            _buildPeriodSection(
                              'Tarde',
                              Icons.wb_twilight,
                              AppColors.mealsColor,
                              tardeList,
                            ),
                            _buildPeriodSection(
                              'Noite',
                              Icons.bedtime,
                              AppColors.primary,
                              noiteList,
                            ),
                          ] else if (filteredList.isNotEmpty &&
                              pending.isEmpty) ...[
                            // Se tem itens mas nenhum pendente
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.done_all,
                                      size: 64,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Todos os lembretes feitos!',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedCategory == 'todos'
                                          ? 'Você concluiu todos os lembretes de hoje.'
                                          : 'Você já fez todos os lembretes desta categoria.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Lembretes Concluídos (Retrátil)
                          if (completedList.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showCompleted = !_showCompleted;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showCompleted
                                          ? Icons.expand_more
                                          : Icons.navigate_next,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'O que já foi feito',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${completedList.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showCompleted) ...[
                              const SizedBox(height: 8),
                              ...completedList.map((r) {
                                final (icon, iconBg, accentColor) =
                                    _categoriaIcon(r.categoria);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Opacity(
                                    opacity: 0.6,
                                    child: ReminderWithAudio(
                                      icon: icon,
                                      iconBg: iconBg,
                                      iconColor: Colors.white,
                                      accentColor: accentColor,
                                      title: r.titulo,
                                      time: r.horarioFormatado,
                                      audioPath: r.audioPath == 'ia_generated'
                                          ? null
                                          : r.audioPath,
                                      ttsText: r.audioPath == 'ia_generated'
                                          ? r.medicamentoAudioTexto
                                          : null,
                                      status: reminderVisualStatusFromLembrete(
                                        r,
                                      ),
                                      onTap: () {
                                        _stopAllAudioAndTts();
                                        Navigator.pushNamed(
                                          context,
                                          '/reminder-detail',
                                          arguments: r,
                                        );
                                      },
                                      onStatusTap: () async {
                                        _stopAllAudioAndTts();
                                        await LembreteService.instance
                                            .alternarConclusao(r.id);
                                        _loadReminders();
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],

                          // Estado vazio (sem nenhum lembrete total)
                          if (filteredList.isEmpty) ...[
                            const SizedBox(height: 48),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_off,
                                    size: 64,
                                    color: AppColors.outlineVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedCategory == 'todos'
                                        ? 'Nada para lembrar hoje'
                                        : 'Nada deste tipo',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedCategory == 'todos'
                                        ? 'Aperte o botão de voz na tela inicial para criar um lembrete.'
                                        : 'Você não tem lembretes desta categoria.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Meus Lembretes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              _stopAllAudioAndTts();
              await Navigator.pushNamed(context, '/elderly-profile');
              _loadProfilePhoto();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56)],
            ),
          ),
        ],
      ),
    );
  }
}
