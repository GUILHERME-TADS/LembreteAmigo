import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/session_role_service.dart';
import '../services/secure_cache_service.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/video_call_service.dart';
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
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    _loadActiveIdosoData();
  }

  Future<void> _loadActiveIdosoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.getActiveIdosoId();
      String nome = 'Idoso';
      String telefone = '';
      String? foto;

      final localFoto = prefs.getString('idoso_foto_path');
      if (localFoto != null && localFoto.isNotEmpty) {
        foto = localFoto;
      }
      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      if (jsonStr != null) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            nome = data['nome'] as String? ?? nome;
            telefone = data['telefone'] as String? ?? telefone;
            if (foto == null ||
                (data['fotoPath'] as String?)?.startsWith('http') == true) {
              foto = data['fotoPath'] as String? ?? foto;
            }
          }
        } catch (_) {}
      }

      bool useFirebase = false;
      try {
        useFirebase = Firebase.apps.isNotEmpty;
      } catch (_) {}

      if (useFirebase && !SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
        try {
          final docPerfil = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .get();
          if (docPerfil.exists && docPerfil.data() != null) {
            final data = docPerfil.data()!;
            nome = data['nome'] as String? ?? nome;
            telefone = data['telefone'] as String? ?? telefone;
            foto = data['fotoPath'] as String? ?? foto;
          }
        } catch (fbErr) {
          debugPrint('Erro ao carregar do Firebase no alerta crítico: $fbErr');
        }
      }

      if (mounted) {
        setState(() {
          _idosoName = nome;
          _idosoPhone = telefone;
          _idosoFoto = foto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do idoso para alerta: $e');
    }
  }

  Future<void> _fazerLigacao() async {
    if (_idosoPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  Future<void> _fazerLigacaoApp(String callType) async {
    if (_isCalling) return;
    setState(() => _isCalling = true);
    try {
      final idosoId = await SessionRoleService.getActiveIdosoId();
      final call = await VideoCallService.instance.initiateCall(
        idosoId: idosoId,
        callType: callType,
        initiatedBy: SessionRoleService.isSupervisor ? 'supervisor' : 'idoso',
      );
      if (call != null && mounted) {
        await VideoCallService.instance.joinCall(
          call.roomName,
          callType: callType,
          callId: call.callId,
          alreadyVerified: true,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível iniciar a chamada pelo aplicativo.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar chamada pelo app: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar chamada: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  Future<void> _resolverLembrete() async {
    final lembrete = widget.lembrete;
    if (lembrete == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Resolver Lembrete',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Deseja marcar este lembrete como resolvido/concluído? Ele não aparecerá mais como alerta crítico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'RESOLVER',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final sucesso = await LembreteService.instance.concluir(lembrete.id);
      if (sucesso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lembrete resolvido com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Fechar a tela de alerta
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível resolver o lembrete agora.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao resolver: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.error, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppRadius.md),
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
                        ElderlyProfileAvatar(
                          fotoPath: _idosoFoto,
                          size: 80,
                          borderWidth: 2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _idosoName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ALERTA: $_idosoName $_motivoAlerta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                            style: TextStyle(
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
                              style: TextStyle(
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
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _isCalling
                                ? null
                                : () => _fazerLigacaoApp('video'),
                            icon: _isCalling
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.videocam, size: 28),
                            label: Text(
                              _isCalling
                                  ? 'Iniciando vídeo...'
                                  : 'Vídeo com $_idosoName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
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
                            onPressed: _isCalling
                                ? null
                                : () => _fazerLigacaoApp('voice'),
                            icon: const Icon(Icons.phone_in_talk, size: 26),
                            label: const Text(
                              'Ligação de Voz pelo App',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
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
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _isCalling ? null : _fazerLigacao,
                            icon: Icon(
                              Icons.phone,
                              size: 22,
                              color: AppColors.onSurfaceVariant,
                            ),
                            label: Text(
                              'Ligar por Telefone Celular (GSM)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.outlineVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (SessionRoleService.isSupervisor &&
                            widget.lembrete != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _resolverLembrete,
                              icon: const Icon(Icons.check_circle, size: 22),
                              label: const Text(
                                'Resolver Lembrete',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _verDetalhes,
                            icon: const Icon(Icons.visibility, size: 22),
                            label: const Text(
                              'Ver Detalhes do Lembrete',
                              style: TextStyle(
                                fontSize: 16,
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
              Row(
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
            icon: Icon(Icons.arrow_back, color: AppColors.onSurface, size: 36),
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
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          dateStr,
          style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
