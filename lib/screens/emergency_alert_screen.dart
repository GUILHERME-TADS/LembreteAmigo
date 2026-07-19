import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/session_role_service.dart';
import '../models/lembrete.dart';
import '../widgets/index.dart';

class EmergencyAlertScreen extends StatefulWidget {
  final Lembrete? lembrete;
  final int totalAlertas;

  const EmergencyAlertScreen({super.key, this.lembrete, this.totalAlertas = 0});

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  String _idosoName = 'Idoso';
  String _idosoPhone = '';
  String? _idosoFoto;

  @override
  void initState() {
    super.initState();
    _loadActiveIdosoData();
  }

  Future<void> _loadActiveIdosoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();

      bool useFirebase = false;
      try {
        useFirebase = Firebase.apps.isNotEmpty;
      } catch (_) {}

      if (useFirebase) {
        final doc = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null && mounted) {
          setState(() {
            _idosoName = doc.data()?['nome'] ?? 'Idoso';
            _idosoPhone = doc.data()?['telefone'] ?? '';
            _idosoFoto = doc.data()?['fotoPath'] as String?;
          });
          return;
        }
      }

      // Fallback local simulation
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) return;
        final data = Map<String, dynamic>.from(decoded);
        if (mounted) {
          setState(() {
            _idosoName = data['nome'] as String? ?? 'Idoso';
            _idosoPhone = data['telefone'] as String? ?? '';
            _idosoFoto = data['fotoPath'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do idoso para alerta: $e');
    }
  }

  Future<void> _fazerLigacao() async {
    if (_idosoPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Telefone do idoso não cadastrado. Adicione um telefone nas configurações.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: _idosoPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o discador.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao abrir discador: $e');
    }
  }

  String get _motivoAlerta {
    final lembrete = widget.lembrete;
    if (lembrete == null) {
      return 'Existe uma atividade recente que precisa de verificacao.';
    }
    switch (reminderVisualStatusFromLembrete(lembrete)) {
      case ReminderStatus.needsHelp:
        return 'pediu ajuda no lembrete "${lembrete.titulo}".';
      case ReminderStatus.missed:
        return 'nao confirmou o lembrete "${lembrete.titulo}".';
      case ReminderStatus.late:
        return 'esta atrasado para confirmar o lembrete "${lembrete.titulo}".';
      default:
        return 'tem uma atividade que precisa de verificacao.';
    }
  }

  IconData get _categoryIcon {
    switch (LembreteCategoria.normalizar(widget.lembrete?.categoria)) {
      case LembreteCategoria.medicacao:
        return Icons.medical_services;
      case LembreteCategoria.refeicoes:
        return Icons.restaurant;
      case LembreteCategoria.exercicio:
        return Icons.directions_walk;
      case LembreteCategoria.hidratacao:
        return Icons.water_drop;
      default:
        return Icons.notifications;
    }
  }

  void _verDetalhes() {
    final lembrete = widget.lembrete;
    if (lembrete == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamed(
      context,
      '/supervisor-reminder-detail',
      arguments: {
        'title': lembrete.titulo,
        'time': lembrete.horarioFormatado,
        'iconData': _categoryIcon,
        'accentColor': AppColors.error,
        'category': LembreteCategoria.nome(lembrete.categoria),
        'lembrete': lembrete,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              const VolumeWarningBanner(),
              _buildTopBar(context),
              _buildStatusBar(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error, width: 3),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.error, color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'ALERTA CRÍTICO',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerHigh,
                            border: Border.all(color: AppColors.outlineVariant),
                            image: _idosoFoto != null && _idosoFoto!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_idosoFoto!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _idosoFoto == null || _idosoFoto!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _idosoName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ALERTA: $_idosoName $_motivoAlerta',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (widget.lembrete != null) ...[
                          Text(
                            '${LembreteCategoria.nome(widget.lembrete!.categoria)} - ${widget.lembrete!.horarioFormatado}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          if (widget.totalAlertas > 1) ...[
                            const SizedBox(height: 8),
                            Text(
                              '+ ${widget.totalAlertas - 1} outro${widget.totalAlertas == 2 ? '' : 's'} alerta${widget.totalAlertas == 2 ? '' : 's'} ativo${widget.totalAlertas == 2 ? '' : 's'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton.icon(
                            onPressed: _fazerLigacao,
                            icon: const Icon(Icons.phone, size: 28),
                            label: Text(
                              'Ligar para $_idosoName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _verDetalhes,
                            icon: const Icon(Icons.visibility, size: 24),
                            label: const Text(
                              'Ver Detalhes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerHigh,
                              foregroundColor: AppColors.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Modo Assistido Ativo • V. 1.0',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.onSurface,
              size: 36,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final now = DateTime.now();
    const diasSemana = [
      'Domingo',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
    ];
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
    final String timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final String dateStr =
        '${diasSemana[now.weekday % 7]}, ${now.day} de ${meses[now.month - 1]}';

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          dateStr,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
