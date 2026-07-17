import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/supervisor_ai_service.dart';
import '../utils/debounce.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final LembreteService _service = LembreteService.instance;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedStatus = 'Todos';
  SupervisorInsights? _aiPatterns;
  bool _aiPatternsLoading = false;
  final Debouncer _searchDebouncer = Debouncer(delay: Duration(milliseconds: 300));

  @override
  void initState() {
    super.initState();
    _service.carregar();
    Connectivity().checkConnectivity().then(_updateOnlineStatus);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateOnlineStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _updateOnlineStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    final online = results.any(
      (r) => r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
    if (_isOnline != online) {
      setState(() {
        _isOnline = online;
      });
    }
  }

  Color _categoriaColor(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return AppColors.medicationsColor;
      case 'refeicoes':
        return AppColors.mealsColor;
      case 'exercicio':
        return AppColors.tertiaryContainer;
      case 'hidratacao':
        return AppColors.voiceFeedbackBlue;
      default:
        return AppColors.customColor;
    }
  }

  IconData _categoriaIcon(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return Icons.medication;
      case 'refeicoes':
        return Icons.restaurant;
      case 'exercicio':
        return Icons.directions_walk;
      case 'hidratacao':
        return Icons.water_drop;
      default:
        return Icons.notifications;
    }
  }

  String _categoriaLabel(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return 'Remédio';
      case 'refeicoes':
        return 'Refeição';
      case 'exercicio':
        return 'Exercício';
      case 'hidratacao':
        return 'Hidratação';
      default:
        return 'Personalizado';
    }
  }

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Hoje';
    } else if (compareDate == yesterday) {
      return 'Ontem';
    } else {
      const meses = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ];
      return '${date.day.toString().padLeft(2, '0')} de ${meses[date.month - 1]} de ${date.year}';
    }
  }

  void _showPhotoDialog(BuildContext context, Lembrete lembrete) {
    final photoPath = lembrete.medicamentoFotoPath;
    if (photoPath == null) return;

    showDialog(
      context: context,
      builder: (context) {
        ImageProvider imageProvider;
        if (photoPath.startsWith('assets/')) {
          imageProvider = AssetImage(photoPath);
        } else {
          imageProvider = FileImage(File(photoPath));
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Foto do Lembrete', style: TextStyle(fontWeight: FontWeight.bold)),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Não foi possível carregar a imagem'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  lembrete.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SupervisorDrawer(currentRoute: '/activity-history'),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.history,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ValueListenableBuilder<List<Lembrete>>(
                valueListenable: _service.notifier,
                builder: (context, lembretes, _) {
                  var list = List<Lembrete>.from(lembretes);
                  
                  if (_selectedCategory != 'Todos') {
                    list = list.where((l) => l.categoria == _selectedCategory).toList();
                  }

                  if (_selectedStatus == 'Concluídos') {
                    list = list.where((l) => l.concluido).toList();
                  } else if (_selectedStatus == 'Pendentes') {
                    list = list.where((l) => !l.concluido).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    list = list.where((l) =>
                      l.titulo.toLowerCase().contains(query) ||
                      _categoriaLabel(l.categoria).toLowerCase().contains(query)
                    ).toList();
                  }

                  list.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Histórico de Atividades',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatsHeader(lembretes),
                        _buildPatternAnalysisButton(lembretes),
                        if (_aiPatterns != null) ...[
                          _buildPatternAnalysisResults(),
                        ],
                        _buildSearchAndFilters(),
                        const SizedBox(height: 10),
                        if (list.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(Icons.history, size: 64, color: AppColors.outlineVariant),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Nenhuma atividade encontrada',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          _buildGroupedActivityList(list),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternAnalysisButton(List<Lembrete> todos) {
    if (todos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _aiPatternsLoading
              ? null
              : () => _analyzePatterns(todos),
          icon: _aiPatternsLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(
            _aiPatternsLoading
                ? 'Analisando padrões...'
                : 'Analisar Padrões com IA',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatternAnalysisResults() {
    final p = _aiPatterns!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'PADRÕES IDENTIFICADOS (IA)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _aiPatterns = null),
                child: const Icon(Icons.close, size: 18, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.summary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.onSurface,
            ),
          ),
          if (p.insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...p.insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Expanded(
                    child: Text(
                      i,
                      style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (p.attentionPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'ATENÇÃO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            ...p.attentionPoints.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a,
                      style: const TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (p.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'SUGESTÕES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            ...p.suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _analyzePatterns(List<Lembrete> todos) async {
    if (_aiPatternsLoading) return;
    setState(() => _aiPatternsLoading = true);
    try {
      final insights = await SupervisorAIService.instance.getDailySummary();
      if (mounted) {
        setState(() {
          _aiPatterns = insights;
          _aiPatternsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _aiPatternsLoading = false);
    }
  }

  Widget _buildStatsHeader(List<Lembrete> todos) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final total = todos.length;
    final concluidos = todos.where((l) => l.concluido).length;
    final pct = total > 0 ? (concluidos / total) : 0.0;

    final totalRemedios = todos.where((l) => l.categoria == 'medicacao').length;
    final concluidosRemedios = todos.where((l) => l.categoria == 'medicacao' && l.concluido).length;

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ADESÃO GERAL DO IDOSO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _isOnline ? Colors.green : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? Colors.green : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 6,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      color: pct >= 0.8
                          ? Colors.green
                          : (pct >= 0.5 ? Colors.orange : AppColors.error),
                    ),
                  ),
                  Text(
                    '${(pct * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$concluidos de $total concluídos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Histórico total registrado',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.medication_outlined, color: AppColors.medicationsColor, size: 20),
                    const SizedBox(height: 4),
                    const Text('Remédios', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    Text(
                      '$concluidosRemedios/$totalRemedios',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (val) {
                _searchDebouncer.call(() {
                  if (mounted) {
                    setState(() {
                      _searchQuery = val;
                    });
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Pesquisar por nome ou categoria...',
                prefixIcon: Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'FILTRAR POR CATEGORIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          const Text(
            'FILTRAR POR STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusChips(),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final Map<String, String> categories = {
      'Todos': 'Todas Categorias',
      'medicacao': 'Remédios',
      'refeicoes': 'Refeições',
      'exercicio': 'Exercícios',
      'hidratacao': 'Hidratação',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.entries.map((entry) {
          final isSelected = _selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceContainerLowest,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = entry.key;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChips() {
    final statuses = ['Todos', 'Concluídos', 'Pendentes'];

    return Row(
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              status,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.secondary,
            backgroundColor: AppColors.surfaceContainerLowest,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedStatus = status;
                });
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupedActivityList(List<Lembrete> todos) {
    List<Widget> listItems = [];
    DateTime? lastDate;

    for (final lembrete in todos) {
      final date = lembrete.criadoEm;
      final bool isNewDay = lastDate == null ||
          lastDate.day != date.day ||
          lastDate.month != date.month ||
          lastDate.year != date.year;
      
      if (isNewDay) {
        lastDate = date;
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              _formatHeaderDate(date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }

      listItems.add(
        _activityCard(lembrete),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: listItems,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Builder(
      builder: (context) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, color: AppColors.primary, size: 32),
              ),
              const Expanded(
                child: Text(
                  'Lembrete Amigo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );
      }
    );
  }

  Widget _activityCard(Lembrete lembrete) {
    final color = _categoriaColor(lembrete.categoria);
    final icon = _categoriaIcon(lembrete.categoria);
    final categoryLabel = _categoriaLabel(lembrete.categoria);
    final concluido = lembrete.concluido;
    final concluidoComFoto = lembrete.concluidoComFoto;

    final cardAccentColor = concluido ? Colors.green : color;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/supervisor-reminder-detail',
          arguments: {
            'title': lembrete.titulo,
            'time': lembrete.horarioFormatado,
            'iconData': icon,
            'accentColor': color,
            'category': categoryLabel,
            'lembrete': lembrete,
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: cardAccentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cardAccentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: cardAccentColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lembrete.titulo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: concluido ? AppColors.onSurfaceVariant : AppColors.onSurface,
                                decoration: concluido ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    categoryLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      lembrete.horarioFormatado,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (concluidoComFoto && lembrete.medicamentoFotoPath != null) ...[
                                  GestureDetector(
                                    onTap: () => _showPhotoDialog(context, lembrete),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.tertiaryFixedDim.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.tertiaryFixedDim, width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.photo_camera, size: 12, color: AppColors.onTertiaryFixedVariant),
                                          SizedBox(width: 4),
                                          Text(
                                            'Ver Foto',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.onTertiaryFixedVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (concluido)
                        const Icon(Icons.check_circle, color: Colors.green, size: 26)
                      else
                        Icon(
                          Icons.radio_button_unchecked,
                          color: color.withValues(alpha: 0.4),
                          size: 26,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
