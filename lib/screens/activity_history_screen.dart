import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../models/lembrete_evento.dart';
import '../services/lembrete_service.dart';
import '../services/effectiveness_service.dart';
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
  final Debouncer _searchDebouncer = Debouncer(
    delay: Duration(milliseconds: 300),
  );

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
      (r) =>
          r == ConnectivityResult.wifi ||
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
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro',
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
        } else if (kIsWeb || photoPath.startsWith('http')) {
          imageProvider = NetworkImage(photoPath);
        } else {
          imageProvider = FileImage(File(photoPath));
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text(
                  'Foto do Lembrete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                        color: AppColors.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: AppColors.outline,
                            ),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
              child: ValueListenableBuilder<List<LembreteEvento>>(
                valueListenable: _service.eventosNotifier,
                builder: (context, eventos, _) {
                  final occurrences = EffectivenessService.instance
                      .collapseOccurrences(eventos);
                  var list = List<LembreteEvento>.from(occurrences);

                  if (_selectedCategory != 'Todos') {
                    list = list
                        .where((e) => e.categoria == _selectedCategory)
                        .toList();
                  }

                  if (_selectedStatus == 'Concluídos') {
                    list = list.where((e) => e.status.isConcluido).toList();
                  } else if (_selectedStatus == 'Não concluídos') {
                    list = list.where((e) => !e.status.isConcluido).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    list = list
                        .where(
                          (e) =>
                              e.titulo.toLowerCase().contains(query) ||
                              _categoriaLabel(
                                e.categoria,
                              ).toLowerCase().contains(query),
                        )
                        .toList();
                  }

                  list.sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
                  final occurrenceReminders = occurrences
                      .map(_reminderForEvent)
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Histórico de Atividades',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatsHeader(occurrenceReminders),
                        _buildSearchAndFilters(),
                        const SizedBox(height: 10),
                        if (list.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: AppColors.outlineVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma atividade encontrada',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
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

  Widget _buildStatsHeader(List<Lembrete> todos) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final total = todos.length;
    final concluidos = todos.where((l) => l.concluido).length;
    final pct = total > 0 ? (concluidos / total) : 0.0;

    final totalRemedios = todos.where((l) => l.categoria == 'medicacao').length;
    final concluidosRemedios = todos
        .where((l) => l.categoria == 'medicacao' && l.concluido)
        .length;

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
              Text(
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
                    color: _isOnline ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? AppColors.success : AppColors.error,
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
                          ? AppColors.success
                          : (pct >= 0.5 ? AppColors.warning : AppColors.error),
                    ),
                  ),
                  Text(
                    '${(pct * 100).toInt()}%',
                    style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      color: AppColors.medicationsColor,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remédios',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$concluidosRemedios/$totalRemedios',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome ou categoria...',
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
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
          Text(
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
      'medicacao': 'Medicação',
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
    final statuses = ['Todos', 'Concluídos', 'Não concluídos'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
      ),
    );
  }

  Widget _buildGroupedActivityList(List<LembreteEvento> todos) {
    List<Widget> listItems = [];
    DateTime? lastDate;

    for (final evento in todos) {
      final date = evento.registradoEm;
      final bool isNewDay =
          lastDate == null ||
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }

      listItems.add(_activityCard(evento));
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
          decoration: BoxDecoration(color: AppColors.surface),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(Icons.menu, color: AppColors.primary, size: 32),
              ),
              Expanded(
                child: Text(
                  'Lembrete Amigo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }

  Lembrete _reminderForEvent(LembreteEvento evento) {
    Lembrete? source;
    for (final reminder in _service.lembretes) {
      if (reminder.id == evento.lembreteId) {
        source = reminder;
        break;
      }
    }
    return (source ??
            Lembrete(
              id: evento.lembreteId,
              titulo: evento.titulo,
              horarioHour: evento.registradoEm.hour,
              horarioMinute: evento.registradoEm.minute,
              categoria: evento.categoria,
              idosoId: evento.idosoId,
            ))
        .copyWith(
          titulo: evento.titulo,
          categoria: evento.categoria,
          criadoEm: evento.registradoEm,
          status: evento.status,
        );
  }

  Widget _activityCard(LembreteEvento evento) {
    final lembrete = _reminderForEvent(evento);
    final eventTime =
        '${evento.registradoEm.hour.toString().padLeft(2, '0')}:'
        '${evento.registradoEm.minute.toString().padLeft(2, '0')}';
    final color = _categoriaColor(lembrete.categoria);
    final icon = _categoriaIcon(lembrete.categoria);
    final categoryLabel = _categoriaLabel(lembrete.categoria);
    final concluido = lembrete.concluido;
    final concluidoComFoto = lembrete.concluidoComFoto;

    final cardAccentColor = concluido ? AppColors.success : color;
    final statusLabel = switch (evento.status) {
      LembreteStatus.concluido => 'Concluído',
      LembreteStatus.concluidoComFoto => 'Concluído com foto',
      LembreteStatus.confirmadoPeloCuidador => 'Confirmado pelo cuidador',
      LembreteStatus.adiado => 'Adiado',
      LembreteStatus.precisaDeAjuda => 'Precisou de ajuda',
      LembreteStatus.perdido => 'Não realizado',
      LembreteStatus.pendente => 'Pendente',
    };

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/supervisor-reminder-detail',
          arguments: {
            'title': lembrete.titulo,
            'time': eventTime,
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
                Container(width: 6, color: cardAccentColor),
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
                                  color: concluido
                                      ? AppColors.onSurfaceVariant
                                      : AppColors.onSurface,
                                  decoration: concluido
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardAccentColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: cardAccentColor,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        eventTime,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (concluidoComFoto &&
                                      lembrete.medicamentoFotoPath != null) ...[
                                    GestureDetector(
                                      onTap: () =>
                                          _showPhotoDialog(context, lembrete),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.tertiaryFixedDim
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: AppColors.tertiaryFixedDim,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.photo_camera,
                                              size: 12,
                                              color: AppColors
                                                  .onTertiaryFixedVariant,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Ver Foto',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors
                                                    .onTertiaryFixedVariant,
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
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 26,
                          )
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
