import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
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
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    TTSService.instance.init();
    _loadReminders();
    _loadProfilePhoto();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  bool _isReminderActiveToday(Lembrete lembrete) {
    final now = DateTime.now();
    if (lembrete.recorrencia == 'diario' || lembrete.repeteTodosOsDias) {
      return true;
    }
    if (lembrete.recorrencia == 'semanal' || lembrete.recorrenciaSemanal) {
      return lembrete.diasSemana.contains(now.weekday);
    }
    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      return (lembrete.diaMes ?? lembrete.criadoEm.day) == now.day;
    }
    if (lembrete.recorrencia == 'quinzenal') {
      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(
            DateTime(
              lembrete.criadoEm.year,
              lembrete.criadoEm.month,
              lembrete.criadoEm.day,
            ),
          )
          .inDays;
      return diffDays >= 0 && diffDays % 15 == 0;
    }
    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      final hojeKey = '${now.year}-${now.month}-${now.day}';
      final criadoKey =
          '${lembrete.criadoEm.year}-${lembrete.criadoEm.month}-${lembrete.criadoEm.day}';
      return hojeKey == criadoKey;
    }
    if (lembrete.recorrencia == 'intervalo' || lembrete.recorrenciaIntervalo) {
      return true;
    }
    return true;
  }

  void _loadReminders() {
    final list = LembreteService.instance.lembretes
        .where((l) => _isReminderActiveToday(l))
        .toList();
    list.sort((a, b) {
      final aMin = a.horarioHour * 60 + a.horarioMinute;
      final bMin = b.horarioHour * 60 + b.horarioMinute;
      return aMin.compareTo(bMin);
    });
    _voiceReminders = list;
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
      final prefs = await SharedPreferences.getInstance();
      final localFoto = prefs.getString('idoso_foto_path');
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

    final countText = list.length == 1 ? '1 tarefa' : '${list.length} tarefas';

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
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
            child: ReminderWithAudio(
              icon: icon,
              iconBg: iconBg,
              iconColor: Colors.white,
              accentColor: accentColor,
              title: r.titulo,
              time: r.horarioFormatado,
              audioPath: r.audioPath,
              status: reminderVisualStatusFromLembrete(r),
              onTap: () {
                _stopAllAudioAndTts();
                if (r.categoria == 'medicacao' && !r.concluido) {
                  Navigator.pushNamed(
                    context,
                    '/take-photo-confirmation',
                    arguments: r.id,
                  );
                } else {
                  if (!r.concluido) {
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.vibrate();
                  }
                  LembreteService.instance.alternarConclusao(r.id);
                }
              },
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
      {'id': 'medicacao', 'label': 'Remédios', 'icon': Icons.medication},
      {'id': 'refeicoes', 'label': 'Refeições', 'icon': Icons.restaurant},
      {'id': 'exercicio', 'label': 'Exercícios', 'icon': Icons.directions_walk},
      {'id': 'hidratacao', 'label': 'Água', 'icon': Icons.water_drop},
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

    final madrugadaList = _getByPeriod(pending, 'madrugada');
    final manhaList = _getByPeriod(pending, 'manha');
    final tardeList = _getByPeriod(pending, 'tarde');
    final noiteList = _getByPeriod(pending, 'noite');

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Suas tarefas do dia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Organizadas por período e categoria',
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
                                ? [const Color(0xFF003709), AppColors.tertiary]
                                : [AppColors.primary, const Color(0xFF1E3A8A)],
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
                                  isAllDone ? Icons.stars : Icons.emoji_events,
                                  color: isAllDone
                                      ? AppColors.tertiaryFixed
                                      : AppColors.secondaryContainer,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isAllDone
                                        ? 'Tudo concluído! Excelente!'
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
                                  ? 'Você realizou todas as suas tarefas. Parabéns por se cuidar!'
                                  : 'Você já fez $completed de $total tarefas de hoje. Continue assim!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
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
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isAllDone
                                            ? AppColors.tertiaryFixedDim
                                            : AppColors.secondaryContainer,
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
                          const Expanded(
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
                            activeColor: AppColors.primary,
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
                            final isSelected = _selectedCategory == cat['id'];
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
                                      _selectedCategory = cat['id'] as String;
                                    });
                                  }
                                },
                                selectedColor: catColor,
                                backgroundColor: AppColors.surfaceContainerHigh,
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

                    if (filteredList.isNotEmpty)
                      AudioPlayerCard(
                        subtitle: _selectedCategory == 'todos'
                            ? 'Ouça todas as tarefas de hoje'
                            : 'Ouça tarefas de ${_selectedCategory == 'medicacao'
                                  ? 'remédios'
                                  : _selectedCategory == 'refeicoes'
                                  ? 'refeições'
                                  : _selectedCategory == 'exercicio'
                                  ? 'exercícios'
                                  : 'água'}',
                        audioPath: filteredList.isNotEmpty
                            ? filteredList.last.audioPath
                            : null,
                        textsToSpeak: () {
                          final catLabel = _selectedCategory == 'medicacao'
                              ? 'remédios'
                              : _selectedCategory == 'refeicoes'
                              ? 'refeições'
                              : _selectedCategory == 'exercicio'
                              ? 'exercícios'
                              : _selectedCategory == 'hidratacao'
                              ? 'lembretes de água'
                              : 'tarefas';
                          final introText = filteredList.isEmpty
                              ? 'Você não tem tarefas nesta categoria.'
                              : isAllDone
                              ? 'Muito bem! Você já fez todas as suas $catLabel de hoje!'
                              : 'Aqui estão suas $catLabel de hoje:';
                          return [
                            introText,
                            ...filteredList.map((l) {
                              final statusSuffix = l.concluido
                                  ? ' já está pronto.'
                                  : l.status == LembreteStatus.adiado
                                  ? ' ficou para mais tarde.'
                                  : '';
                              return '${l.titulo} às ${PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute)}$statusSuffix';
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
                        const Color(0xFF455A64),
                        madrugadaList,
                      ),
                      _buildPeriodSection(
                        'Manhã',
                        Icons.wb_sunny,
                        Colors.orange,
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
                        Colors.indigo,
                        noiteList,
                      ),
                    ] else if (filteredList.isNotEmpty && pending.isEmpty) ...[
                      // Se tem itens mas nenhum pendente
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.done_all,
                                size: 64,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Todas as tarefas feitas!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedCategory == 'todos'
                                    ? 'Você concluiu todas as tarefas de hoje.'
                                    : 'Você concluiu todas as tarefas nesta categoria.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _showCompleted
                                    ? Icons.expand_more
                                    : Icons.navigate_next,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tarefas Concluídas',
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
                                  style: const TextStyle(
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
                          final (icon, iconBg, accentColor) = _categoriaIcon(
                            r.categoria,
                          );
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
                                audioPath: r.audioPath,
                                status: reminderVisualStatusFromLembrete(r),
                                onTap: () {
                                  _stopAllAudioAndTts();
                                  LembreteService.instance.alternarConclusao(
                                    r.id,
                                  );
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
                              Icons.notifications_none,
                              size: 64,
                              color: AppColors.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedCategory == 'todos'
                                  ? 'Nenhum lembrete criado'
                                  : 'Nenhum lembrete nesta categoria',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedCategory == 'todos'
                                  ? 'Use o botão de voz na tela inicial para criar lembretes.'
                                  : 'Você não tem tarefas registradas nesta categoria.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Todos os Lembretes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              MeExplicaButton(
                textoExplicacao:
                    'Olá! Esta é a tela com todas as suas tarefas de hoje, organizadas do horário mais cedo para o mais tarde.',
                onTapped: _stopAllAudioAndTts,
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
            child: ElderlyProfileAvatar(fotoPath: _fotoPath, size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.home, 'Início', false, () {
                _stopAllAudioAndTts();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/elderly-home',
                  (route) => false,
                );
              }),
              _bottomNavItem(Icons.list_alt, 'Lembretes', true, null),
              _bottomNavItem(Icons.help_center, 'Ajuda', false, () {
                _stopAllAudioAndTts();
                Navigator.pushNamed(context, '/elderly-help');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback? onTap,
  ) {
    final itemColor = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: itemColor),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
