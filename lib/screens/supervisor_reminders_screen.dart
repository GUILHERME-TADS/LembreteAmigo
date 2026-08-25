import 'dart:async';
import 'package:flutter/material.dart';

import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../theme/app_theme.dart';
import '../utils/debounce.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class SupervisorRemindersScreen extends StatefulWidget {
  const SupervisorRemindersScreen({super.key});

  @override
  State<SupervisorRemindersScreen> createState() =>
      _SupervisorRemindersScreenState();
}

class _SupervisorRemindersScreenState extends State<SupervisorRemindersScreen> {
  final LembreteService _service = LembreteService.instance;
  String _searchQuery = '';
  String _selectedCategory = 'todos';
  bool _isLoading = true;
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _service.notifier.addListener(_onRemindersChanged);
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _service.notifier.removeListener(_onRemindersChanged);
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      await _service.carregar();
    } catch (e) {
      debugPrint('Erro ao carregar lembretes na tela de gerenciamento: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onRemindersChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Color _categoriaColor(String categoria) {
    switch (LembreteCategoria.normalizar(categoria)) {
      case LembreteCategoria.medicacao:
        return AppColors.medicationsColor;
      case LembreteCategoria.refeicoes:
        return AppColors.mealsColor;
      case LembreteCategoria.exercicio:
        return AppColors.tertiaryContainer;
      case LembreteCategoria.hidratacao:
        return AppColors.voiceFeedbackBlue;
      case LembreteCategoria.consulta:
        return AppColors.primary;
      default:
        return AppColors.customColor;
    }
  }

  IconData _categoriaIcon(String categoria) {
    switch (LembreteCategoria.normalizar(categoria)) {
      case LembreteCategoria.medicacao:
        return Icons.medication_rounded;
      case LembreteCategoria.refeicoes:
        return Icons.restaurant_rounded;
      case LembreteCategoria.exercicio:
        return Icons.directions_walk_rounded;
      case LembreteCategoria.hidratacao:
        return Icons.water_drop_rounded;
      case LembreteCategoria.consulta:
        return Icons.calendar_month_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _getRecorrenciaTexto(Lembrete l) {
    if (l.recorrencia == 'unico' || l.lembreteUnico) {
      return 'Lembrete único';
    } else if (l.recorrencia == 'semanal' || l.recorrenciaSemanal) {
      const diaNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      final dias = l.diasSemana
          .where((d) => d >= 1 && d <= 7)
          .map((d) => diaNomes[d - 1])
          .join(', ');
      return dias.isNotEmpty ? 'Semanal ($dias)' : 'Semanal';
    } else if (l.recorrencia == 'mensal' || l.recorrenciaMensal) {
      return 'Mensal (dia ${l.diaMes ?? l.criadoEm.day})';
    } else if (l.recorrencia == 'quinzenal') {
      return 'A cada 15 dias';
    } else if (l.recorrencia == 'intervalo' || l.recorrenciaIntervalo) {
      return 'A cada ${l.intervaloHoras ?? 8}h';
    } else {
      return 'Todos os dias';
    }
  }

  String _getDuracaoTexto(Lembrete l) {
    if (l.recorrencia == 'unico' || l.lembreteUnico) {
      if (l.dataInicio != null) {
        final d = l.dataInicio!;
        return 'Data: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      return 'Data única';
    }

    if (l.isUsoContinuo || (l.dataFim == null && l.categoria != 'medicacao')) {
      return 'Uso contínuo';
    }

    if (l.dataInicio != null && l.dataFim != null) {
      final i = l.dataInicio!;
      final f = l.dataFim!;
      final iniStr =
          '${i.day.toString().padLeft(2, '0')}/${i.month.toString().padLeft(2, '0')}';
      final fimStr =
          '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
      return '$iniStr até $fimStr';
    }

    if (l.dataFim != null) {
      final f = l.dataFim!;
      return 'Até ${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
    }

    return 'Uso contínuo';
  }

  List<Lembrete> get _filteredReminders {
    var list = _service.lembretes;

    if (_selectedCategory != 'todos') {
      list = list
          .where(
            (l) =>
                LembreteCategoria.normalizar(l.categoria) == _selectedCategory,
          )
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((l) {
        final matchTitle = l.titulo.toLowerCase().contains(query);
        final matchInstructions =
            l.medicamentoInstrucoes?.toLowerCase().contains(query) ?? false;
        final matchDose =
            l.medicamentoDose?.toLowerCase().contains(query) ?? false;
        return matchTitle || matchInstructions || matchDose;
      }).toList();
    }

    // Ordenar por horário
    final sorted = List<Lembrete>.from(list)
      ..sort((a, b) {
        final compH = a.horarioHour.compareTo(b.horarioHour);
        if (compH != 0) return compH;
        return a.horarioMinute.compareTo(b.horarioMinute);
      });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReminders;
    final totalLembretes = _service.lembretes.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            color: AppColors.primary,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todos os Lembretes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              '$totalLembretes ${totalLembretes == 1 ? 'lembrete configurado' : 'lembretes configurados'}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            color: AppColors.primary,
            tooltip: 'Recarregar',
            onPressed: _loadReminders,
          ),
        ],
      ),
      drawer: const SupervisorDrawer(currentRoute: '/supervisor-reminders'),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nome, dose ou instruções...',
                prefixIcon: Icon(Icons.search, color: AppColors.outline),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (val) {
                _searchDebouncer(() {
                  if (mounted) setState(() => _searchQuery = val);
                });
              },
            ),
          ),

          // Chips de Filtro por Categoria
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCategoryChip('todos', 'Todos', Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  LembreteCategoria.medicacao,
                  'Medicação',
                  Icons.medication_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  LembreteCategoria.refeicoes,
                  'Refeições',
                  Icons.restaurant_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  LembreteCategoria.exercicio,
                  'Exercício',
                  Icons.directions_walk_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  LembreteCategoria.hidratacao,
                  'Hidratação',
                  Icons.water_drop_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  LembreteCategoria.personalizado,
                  'Personalizado',
                  Icons.notifications_active_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Lembretes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final lembrete = filtered[index];
                          return _buildReminderCard(lembrete);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Novo Lembrete',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/new-reminder');
          if (result != null) {
            _loadReminders();
          }
        },
      ),
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.none,
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, IconData icon) {
    final isSelected = _selectedCategory == id;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLowest,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() => _selectedCategory = id);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != 'todos'
                  ? 'Nenhum lembrete encontrado'
                  : 'Nenhum lembrete cadastrado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != 'todos'
                  ? 'Tente ajustar os filtros ou os termos da busca.'
                  : 'Cadastre o primeiro remédio ou compromisso do idoso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result =
                    await Navigator.pushNamed(context, '/new-reminder');
                if (result != null) _loadReminders();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cadastrar Lembrete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Lembrete lembrete) {
    final color = _categoriaColor(lembrete.categoria);
    final icon = _categoriaIcon(lembrete.categoria);
    final isMedication =
        LembreteCategoria.normalizar(lembrete.categoria) ==
        LembreteCategoria.medicacao;
    final recorrenciaTexto = _getRecorrenciaTexto(lembrete);
    final duracaoTexto = _getDuracaoTexto(lembrete);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/supervisor-reminder-detail',
            arguments: {
              'title': lembrete.titulo,
              'time': lembrete.horarioFormatado,
              'iconData': icon,
              'accentColor': color,
              'category': LembreteCategoria.nome(lembrete.categoria),
              'lembrete': lembrete,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Ícone, Título e Horário
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lembrete.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMedication &&
                            lembrete.medicamentoDose != null &&
                            lembrete.medicamentoDose!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Dose: ${lembrete.medicamentoDose}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          lembrete.horarioFormatado,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges de Recorrência e Duração
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Badge Recorrência
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          recorrenciaTexto,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge Duração (Uso contínuo ou Datas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          duracaoTexto,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de Áudio Gravado
                  if (lembrete.audioPath != null &&
                      lembrete.audioPath!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 14,
                            color: AppColors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Áudio familiar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Badge de Estoque
                  if (isMedication && lembrete.medicamentoEstoque != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (lembrete.medicamentoEstoqueMinimo != null &&
                                lembrete.medicamentoEstoque! <=
                                    lembrete.medicamentoEstoqueMinimo!)
                            ? AppColors.errorContainer
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: (lembrete.medicamentoEstoqueMinimo != null &&
                                    lembrete.medicamentoEstoque! <=
                                        lembrete.medicamentoEstoqueMinimo!)
                                ? AppColors.onErrorContainer
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Estoque: ${lembrete.medicamentoEstoque}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (lembrete.medicamentoEstoqueMinimo !=
                                          null &&
                                      lembrete.medicamentoEstoque! <=
                                          lembrete.medicamentoEstoqueMinimo!)
                                  ? AppColors.onErrorContainer
                                  : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Instruções (se houver)
              if (lembrete.medicamentoInstrucoes != null &&
                  lembrete.medicamentoInstrucoes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Instruções: ${lembrete.medicamentoInstrucoes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
