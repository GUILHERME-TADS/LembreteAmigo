import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/supervisor_bottom_nav.dart';

class DetailedHistoryScreen extends StatefulWidget {
  const DetailedHistoryScreen({super.key});

  @override
  State<DetailedHistoryScreen> createState() => _DetailedHistoryScreenState();
}

class _DetailedHistoryScreenState extends State<DetailedHistoryScreen> {
  final LembreteService _service = LembreteService.instance;
  bool _isOnline = true;
  Timer? _connectivityTimer;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedStatus = 'Todos';

  @override
  void initState() {
    super.initState();
    _service.carregar();
    _checkConnection();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
      final bool hasNet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != hasNet) {
        setState(() {
          _isOnline = hasNet;
        });
      }
    } catch (_) {
      if (mounted && _isOnline) {
        setState(() {
          _isOnline = false;
        });
      }
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
        return 'Água';
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
                  // Apply filters
                  var list = List<Lembrete>.from(lembretes);
                  
                  // Category Filter
                  if (_selectedCategory != 'Todos') {
                    list = list.where((l) => l.categoria == _selectedCategory).toList();
                  }

                  // Status Filter
                  if (_selectedStatus == 'Concluídos') {
                    list = list.where((l) => l.concluido).toList();
                  } else if (_selectedStatus == 'Pendentes') {
                    list = list.where((l) => !l.concluido).toList();
                  }

                  // Search Filter
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    list = list.where((l) =>
                      l.titulo.toLowerCase().contains(query) ||
                      _categoriaLabel(l.categoria).toLowerCase().contains(query)
                    ).toList();
                  }

                  // Sort: descending by criadoEm date
                  list.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: _isOnline ? AppColors.tertiaryFixedDim : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnline ? 'Conectado' : 'Sem Internet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.05,
                                color: _isOnline ? AppColors.onTertiaryContainer : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Histórico Detalhado',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 16),
                        _buildStatsHeader(lembretes),
                        _buildSearchAndFilters(),
                        const SizedBox(height: 20),
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

  Widget _buildStatsHeader(List<Lembrete> todos) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final total = todos.length;
    final concluidos = todos.where((l) => l.concluido).length;
    final pct = total > 0 ? (concluidos / total) : 0.0;

    final totalRemedios = todos.where((l) => l.categoria == 'medicacao').length;
    final concluidosRemedios = todos.where((l) => l.categoria == 'medicacao' && l.concluido).length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Taxa de Adesão Geral',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(pct * 100).toInt()}% das atividades',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.outlineVariant,
                    color: pct >= 0.8 ? Colors.green : (pct >= 0.5 ? Colors.orange : AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                const Icon(Icons.medication, color: AppColors.medicationsColor, size: 24),
                const SizedBox(height: 4),
                const Text('Remédios', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                Text(
                  '$concluidosRemedios/$totalRemedios',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Pesquisar atividades...',
              prefixIcon: Icon(Icons.search, color: AppColors.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildCategoryChips(),
        const SizedBox(height: 8),
        _buildStatusChips(),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final Map<String, String> categories = {
      'Todos': 'Todas Categorias',
      'medicacao': 'Remédios',
      'refeicoes': 'Refeições',
      'exercicio': 'Exercícios',
      'hidratacao': 'Água',
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
              backgroundColor: AppColors.surfaceContainerLow,
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
            backgroundColor: AppColors.surfaceContainerLow,
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          ),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHigh,
            ),
            child: const Icon(Icons.person, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(Lembrete lembrete) {
    final color = _categoriaColor(lembrete.categoria);
    final icon = _categoriaIcon(lembrete.categoria);
    final categoryLabel = _categoriaLabel(lembrete.categoria);
    final concluido = lembrete.concluido;
    final concluidoComFoto = lembrete.concluidoComFoto;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: concluido ? AppColors.tertiaryFixedDim : color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lembrete.titulo, 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: concluido ? AppColors.onSurfaceVariant : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(categoryLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ),
                    Text(lembrete.horarioFormatado, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                    if (concluidoComFoto && lembrete.medicamentoFotoPath != null) ...[
                      GestureDetector(
                        onTap: () => _showPhotoDialog(context, lembrete),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixedDim.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: AppColors.tertiaryFixedDim, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera, size: 12, color: AppColors.onTertiaryFixedVariant),
                              SizedBox(width: 4),
                              Text(
                                'Ver Foto',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.onTertiaryFixedVariant),
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
          if (concluido)
            const Icon(Icons.check_circle, color: AppColors.tertiaryFixedDim, size: 24)
          else
            Icon(Icons.circle_outlined, color: color.withValues(alpha: 0.5), size: 24),
        ],
      ),
    );
  }
}
