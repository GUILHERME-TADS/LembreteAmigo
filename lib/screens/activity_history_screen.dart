import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/volume_warning_banner.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final LembreteService _service = LembreteService.instance;
  bool _isOnline = true;
  Timer? _connectivityTimer;

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
        return 'Hidratação';
      default:
        return 'Personalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(context),
            Expanded(
              child: ValueListenableBuilder<List<Lembrete>>(
                valueListenable: _service.notifier,
                builder: (context, lembretes, _) {
                  final concluidos = lembretes.where((l) => l.concluido).toList()
                    ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

                  final pendentes = lembretes.where((l) => !l.concluido).toList()
                    ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

                  final todos = [...concluidos, ...pendentes];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Histórico de Atividades',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_list, size: 20, color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text('${todos.length} itens', style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (todos.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(Icons.history, size: 64, color: AppColors.outlineVariant),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Nenhuma atividade ainda',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          for (final lembrete in todos)
                            _activityCard(
                              lembrete.titulo,
                              lembrete.horarioFormatado,
                              _categoriaIcon(lembrete.categoria),
                              _categoriaColor(lembrete.categoria),
                              _categoriaLabel(lembrete.categoria),
                              lembrete.concluido,
                              lembrete.concluidoComFoto,
                            ),
                        const SizedBox(height: 96),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
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

  Widget _activityCard(String message, String time, IconData icon, Color color, String category, bool concluido, bool concluidoComFoto) {
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
                Text(message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: concluido ? AppColors.onSurfaceVariant : AppColors.onSurface)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                    if (concluidoComFoto) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryFixedDim.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera, size: 12, color: AppColors.onTertiaryFixedVariant),
                            SizedBox(width: 4),
                            Text(
                              'Foto Enviada',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant),
                            ),
                          ],
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

  Widget _buildBottomNav() {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Início', false),
          _navItem(Icons.history, 'Histórico', true),
          _navItem(Icons.help_center, 'Ajuda', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.secondaryContainer : null,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
