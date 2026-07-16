import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../widgets/index.dart';
import '../widgets/custom_time_picker.dart';
import '../models/lembrete.dart';
import '../utils/period_helper.dart';

class ElderlyProfileScreen extends StatefulWidget {
  const ElderlyProfileScreen({super.key});

  @override
  State<ElderlyProfileScreen> createState() => _ElderlyProfileScreenState();
}

class _ElderlyProfileScreenState extends State<ElderlyProfileScreen> {
  String _nome = 'Não cadastrado';
  String _dataNasc = 'Não informada';
  String _telefone = 'Não informado';
  String _endereco = 'Não informado';
  String? _fotoPath;
  bool _isLoading = true;
  bool _isConnectionActive = false;


  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  @override
  void dispose() {
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile({bool reloadPhoto = true}) async {
    await LembreteService.instance.carregar();
    try {
      final prefs = await SharedPreferences.getInstance();

      String status = 'pending';
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          status = data['status'] as String? ?? 'pending';
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isConnectionActive = status == 'active';
        });
      }

      // 1. Carrega os dados locais do perfil (SharedPreferences) primeiro como baseline
      String nome = 'Não cadastrado';
      String dataNasc = 'Não informada';
      String telefone = 'Não informado';
      String endereco = 'Não informado';

      final localFoto = prefs.getString('idoso_foto_path');

      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        nome = (data['nome'] as String?)?.isNotEmpty == true
            ? data['nome'] as String
            : 'Não cadastrado';
        dataNasc = (data['dataNascimento'] as String?)?.isNotEmpty == true
            ? data['dataNascimento'] as String
            : 'Não informada';
        telefone = (data['telefone'] as String?)?.isNotEmpty == true
            ? data['telefone'] as String
            : 'Não informado';
        endereco = (data['endereco'] as String?)?.isNotEmpty == true
            ? data['endereco'] as String
            : 'Não informado';
      }

      String? fotoPath = reloadPhoto ? localFoto : _fotoPath;

      bool isRealValue(String v) =>
          v.isNotEmpty &&
          v != 'Minha Conta' &&
          v != 'Não cadastrado' &&
          v != 'Não informada' &&
          v != 'Não informado';

      // 2. Se o Firebase estiver ativo, tenta preencher campos vazios com dados da nuvem
      if (_useFirebase) {
        try {
          final idosoId = await SessionRoleService.getActiveIdosoId();
          final docPerfil = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .get();
          final docIdoso = await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .get();

          if (docIdoso.exists && docIdoso.data() != null) {
            final data = docIdoso.data()!;
            if (!isRealValue(nome)) {
              final v = data['nome']?.toString() ?? '';
              if (isRealValue(v)) nome = v;
            }
            if (!isRealValue(dataNasc)) {
              final v = data['dataNascimento']?.toString() ?? '';
              if (isRealValue(v)) dataNasc = v;
            }
            if (!isRealValue(telefone)) {
              final v = data['telefone']?.toString() ?? '';
              if (isRealValue(v)) telefone = v;
            }
            if (!isRealValue(endereco)) {
              final v = data['endereco']?.toString() ?? '';
              if (isRealValue(v)) endereco = v;
            }
          }

          if (docPerfil.exists && docPerfil.data() != null) {
            final data = docPerfil.data()!;
            if (!isRealValue(nome)) {
              final v = data['nome']?.toString() ?? '';
              if (isRealValue(v)) nome = v;
            }
            if (!isRealValue(dataNasc)) {
              final v = data['dataNascimento']?.toString() ?? '';
              if (isRealValue(v)) dataNasc = v;
            }
            if (!isRealValue(telefone)) {
              final v = data['telefone']?.toString() ?? '';
              if (isRealValue(v)) telefone = v;
            }
            if (!isRealValue(endereco)) {
              final v = data['endereco']?.toString() ?? '';
              if (isRealValue(v)) endereco = v;
            }

            final firestoreStatus = data['status'] as String? ?? 'pending';
            final firestoreSupervisorId = data['supervisorId'] as String?;

            // Save updated connection fields to cache
            final jsonStr = prefs.getString('idoso_perfil');
            if (jsonStr != null) {
              try {
                final localData = jsonDecode(jsonStr) as Map<String, dynamic>;
                localData['status'] = firestoreStatus;
                localData['supervisorId'] = firestoreSupervisorId;
                await prefs.setString('idoso_perfil', jsonEncode(localData));
              } catch (_) {}
            }

            if (mounted) {
              setState(() {
                _isConnectionActive = firestoreStatus == 'active';
              });
            }
            if (firestoreStatus == 'active' && firestoreSupervisorId != null) {
              await prefs.setBool('elderly_autonomous_mode', false);
            }
          }

          if (reloadPhoto) {
            // Smart local-first photo path sync
            bool isLocalFile =
                localFoto != null && !localFoto.startsWith('avatar_');
            bool localFileExists = isLocalFile && File(localFoto).existsSync();

            if (!localFileExists) {
              String? firestoreFoto;
              if (docIdoso.exists && docIdoso.data() != null) {
                final data = docIdoso.data()!;
                firestoreFoto = data['fotoPath'] as String?;
              }
              if (docPerfil.exists && docPerfil.data() != null) {
                final data = docPerfil.data()!;
                firestoreFoto = data['fotoPath'] as String? ?? firestoreFoto;
              }
              if (firestoreFoto != null && firestoreFoto.isNotEmpty) {
                fotoPath = firestoreFoto;
                if (firestoreFoto.startsWith('avatar_') ||
                    firestoreFoto.startsWith('http') ||
                    File(firestoreFoto).existsSync()) {
                  await prefs.setString('idoso_foto_path', firestoreFoto);
                }
              }
            }
          }
        } catch (firebaseError) {
          debugPrint(
            'Erro ao sincronizar perfil do Firebase (usando dados locais): $firebaseError',
          );
        }
      }

      if (mounted) {
        setState(() {
          _nome = nome;
          _dataNasc = dataNasc;
          _telefone = telefone;
          _endereco = endereco;
          _fotoPath = fotoPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro no _loadProfile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _desvincularAjudante(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desconectar Ajudante?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: const Text(
          'Deseja realmente desconectar o aplicativo do celular do seu ajudante? Você voltará ao modo autônomo.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NÃO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIM, DESCONECTAR', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final docId = prefs.getString('paired_idoso_id');
      Object? syncError;
      if (docId != null && docId != 'idoso_autonomo') {
        if (_useFirebase) {
          try {
            final batch = FirebaseFirestore.instance.batch();
            batch.set(
              FirebaseFirestore.instance.collection('idoso_perfil').doc(docId),
              {
                'supervisorId': null,
                'status': 'pending',
                'pairingCode': null,
                'pairingCodeExpires': null,
              },
              SetOptions(merge: true),
            );
            batch.set(
              FirebaseFirestore.instance.collection('idosos').doc(docId),
              {
                'supervisorId': null,
                'status': 'pending',
                'pairingCode': null,
                'pairingCodeExpires': null,
              },
              SetOptions(merge: true),
            );
            await batch.commit();
          } catch (e) {
            syncError = e;
            debugPrint('Erro ao sincronizar desvinculo na nuvem: $e');
          }
        }
      }
      await prefs.setString('paired_idoso_id', 'idoso_autonomo');
      await prefs.setBool('elderly_autonomous_mode', true);

      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
        data['status'] = 'pending';
        data['supervisorId'] = null;
        await prefs.setString('idoso_perfil', jsonEncode(data));
      }

      final message = syncError == null
          ? 'Aplicativo desconectado com sucesso.'
          : 'Ajudante desconectado neste aparelho. A sincronizacao com a nuvem sera tentada novamente quando houver conexao.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      await TTSService.instance.falar(message, caller: this);
      await _loadProfile();
    } catch (e) {
      debugPrint('Erro ao desvincular: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desconectar ajudante: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _showEditDeleteDialog(Lembrete lembrete) async {
    TTSService.instance.parar(caller: this);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          title: Text(
            lembrete.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O que você deseja fazer?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // Button 1: Mudar Horário
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _adjustTime(lembrete);
                    });
                  },
                  icon: const Icon(Icons.access_time, size: 28),
                  label: const Text(
                    'MUDAR HORÁRIO',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppColors.secondary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Button 2: Mudar Nome
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _editTitle(lembrete);
                    });
                  },
                  icon: const Icon(Icons.edit, size: 28),
                  label: const Text(
                    'MUDAR NOME',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppColors.outlineVariant,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Button 3: Excluir Lembrete
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _deleteReminder(lembrete);
                    });
                  },
                  icon: const Icon(Icons.delete, size: 28),
                  label: const Text(
                    'APAGAR LEMBRETE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Button 4: Cancelar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'VOLTAR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _adjustTime(Lembrete lembrete) async {
    final picked = await showCustomTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: lembrete.horarioHour,
        minute: lembrete.horarioMinute,
      ),
    );
    if (picked == null) return;
    LembreteService.instance.atualizarHorario(
      lembrete.id,
      picked.hour,
      picked.minute,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horário atualizado com sucesso!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTitle(Lembrete lembrete) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditTitleDialog(initialValue: lembrete.titulo),
    );

    if (result == null || result.isEmpty || result == lembrete.titulo) return;
    LembreteService.instance.atualizarTitulo(lembrete.id, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nome atualizado com sucesso!')),
    );
  }

  Future<void> _deleteReminder(Lembrete lembrete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apagar lembrete?'),
          content: Text(
            'Você quer mesmo apagar o lembrete "${lembrete.titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NÃO, VOLTAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
              ),
              child: const Text('SIM, APAGAR'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    LembreteService.instance.remover(lembrete.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lembrete excluído.')));
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Meu Perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 6),
              MeExplicaButton(
                textoExplicacao:
                    'Olá! Esta é a tela com as suas informações. Aqui você vê o seu nome e telefone. Para mudar sua foto, aperte em cima do círculo da foto. Para mudar seu nome ou se conectar com um ajudante, use os botões da lista abaixo.',
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 48), // Mantém o equilíbrio visual com o botão de voltar no lado oposto
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Medicamentos reais filtrados de LembreteService
    final medicamentosReais = LembreteService.instance.lembretes
        .where((l) => l.categoria == 'medicacao')
        .toList();
    final lembretesReais = LembreteService.instance.lembretes
        .where((l) => l.categoria != 'medicacao')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF1565C0), // Royal Blue
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _selectProfilePhotoOptions,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                      image:
                                          _fotoPath != null &&
                                              !_fotoPath!.startsWith('avatar_')
                                          ? (_fotoPath!.startsWith('http')
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      _fotoPath!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : (File(_fotoPath!).existsSync()
                                                      ? DecorationImage(
                                                          image: FileImage(
                                                            File(_fotoPath!),
                                                          ),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null))
                                          : null,
                                    ),
                                    child:
                                        _fotoPath == null ||
                                            _fotoPath!.startsWith('avatar_') ||
                                            (!_fotoPath!.startsWith('http') &&
                                                !File(_fotoPath!).existsSync())
                                        ? _buildAvatarIconChild()
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _selectProfilePhotoOptions,
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Alterar Foto',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () =>
                                      _falarInfo('Nome completo', _nome),
                                  child: Text(
                                    _nome.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _falarInfo(
                                    'Data de nascimento',
                                    _dataNasc,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.cake,
                                          size: 18,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _dataNasc,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _sectionTitle('Informações de Contato'),
                          const SizedBox(height: 12),
                          _infoRow(
                            Icons.phone,
                            'Telefone de Contato',
                            _telefone,
                          ),
                          _infoRow(
                            Icons.location_on,
                            'Seu Endereço',
                            _endereco,
                          ),
                          _sectionTitle(
                            'Medicamentos em Uso (Remédios cadastrados)',
                          ),
                          const SizedBox(height: 12),
                          if (medicamentosReais.isEmpty)
                            _buildEmptyState(
                              'Nenhum lembrete de medicamento ativo cadastrado.',
                              Icons.medication_outlined,
                            )
                          else
                            ...medicamentosReais.map((med) {
                              return _medicationItem(med);
                            }),
                          const SizedBox(height: 24),
                          _sectionTitle('Lembretes e Rotina'),
                          const SizedBox(height: 12),
                          if (lembretesReais.isEmpty)
                            _buildEmptyState(
                              'Nenhum lembrete de rotina cadastrado.',
                              Icons.notifications_none,
                            )
                          else
                            ...lembretesReais.map((lembrete) {
                              return _reminderItem(lembrete);
                            }),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (!_isConnectionActive) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 64,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        TTSService.instance.parar(caller: this);
                                        await Navigator.pushNamed(
                                          context,
                                          '/elderly-pairing',
                                        );
                                        _loadProfile();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link, size: 28),
                                          SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              'CONECTAR COM AJUDANTE',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 64,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _desvincularAjudante(context),
                                      icon: const Icon(Icons.link_off, size: 28, color: Colors.white),
                                      label: const Text(
                                        'DESCONECTAR AJUDANTE',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                                  const SizedBox(height: 16),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      TTSService.instance.parar(caller: this);
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/edit-profile',
                                      );
                                      if (result == true) {
                                        _loadProfile();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.secondaryContainer,
                                      foregroundColor:
                                          AppColors.onSecondaryFixed,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit, size: 28),
                                        SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'ALTERAR MEUS DADOS',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      TTSService.instance.parar(caller: this);
                                      await Navigator.pushNamed(
                                        context,
                                        '/voice-settings',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondaryContainer,
                                      foregroundColor: AppColors.onSecondaryFixed,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.record_voice_over, size: 28),
                                        SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'VOZ E ESCUTA DO ALEX',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      TTSService.instance.parar(caller: this);
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text('Sair do Modo Idoso?', style: TextStyle(fontWeight: FontWeight.bold)),
                                          content: const Text(
                                            'Deseja realmente voltar para a tela de escolha de perfil? Suas informações e lembretes continuarão salvos normalmente.',
                                            style: TextStyle(fontSize: 18),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('NÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('SIM, SAIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await SessionRoleService.exitElderlyModeOnly();
                                        if (context.mounted) {
                                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.onSurface,
                                      side: const BorderSide(color: AppColors.outlineVariant, width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.swap_horiz, size: 28),
                                        SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'SAIR DO MODO IDOSO',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  void _falarInfo(String label, String value) {
    TTSService.instance.falar('$label: $value', caller: this);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _falarInfo(label, value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _medicationItem(Lembrete med) {
    final color = AppColors.medicationsColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditDeleteDialog(med),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 10, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.medication,
                              color: color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  med.titulo,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      med.horarioFormatado,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final spoken = PeriodHelper.getSpokenTimeFromStr(
                                med.horarioFormatado,
                              );
                              TTSService.instance.falar(
                                'Remédio: ${med.titulo} às $spoken',
                                caller: this,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.volume_up,
                                color: color,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.outline,
                            size: 28,
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
      ),
    );
  }

  Widget _reminderItem(Lembrete lembrete) {
    IconData icon = Icons.notifications;
    Color color = AppColors.customColor;
    String catName = 'lembrete';
    switch (lembrete.categoria) {
      case 'refeicoes':
        icon = Icons.restaurant;
        color = AppColors.mealsColor;
        catName = 'refeição';
        break;
      case 'hidratacao':
        icon = Icons.water_drop;
        color = AppColors.voiceFeedbackBlue;
        catName = 'água';
        break;
      case 'exercicio':
        icon = Icons.directions_walk;
        color = const Color(0xFF2E7D32);
        catName = 'exercício';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditDeleteDialog(lembrete),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 10, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  lembrete.titulo,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      lembrete.horarioFormatado,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final spoken = PeriodHelper.getSpokenTimeFromStr(
                                lembrete.horarioFormatado,
                              );
                              TTSService.instance.falar(
                                'Lembrete de $catName: ${lembrete.titulo} às $spoken',
                                caller: this,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.volume_up,
                                color: color,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.outline,
                            size: 28,
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
      ),
    );
  }

  Widget _buildAvatarIconChild() {
    if (_fotoPath == null) {
      return const Icon(
        Icons.person,
        size: 48,
        color: AppColors.onPrimaryContainer,
      );
    }
    IconData icon = Icons.person;
    Color color = AppColors.onPrimaryContainer;
    if (_fotoPath == 'avatar_1') {
      icon = Icons.person;
      color = Colors.blue;
    } else if (_fotoPath == 'avatar_2') {
      icon = Icons.face;
      color = Colors.green;
    } else if (_fotoPath == 'avatar_3') {
      icon = Icons.portrait;
      color = Colors.orange;
    }
    return Icon(icon, size: 48, color: color);
  }

  Future<void> _selectProfilePhotoOptions() async {
    TTSService.instance.parar();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Foto de Perfil',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primary,
                  size: 28,
                ),
                title: const Text(
                  'Tirar foto (Câmera)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.pushNamed(
                    context,
                    '/take-photo-confirmation',
                    arguments: 'profile_photo',
                  );
                  if (result != null && result is String) {
                    setState(() {
                      _fotoPath = result;
                    });
                    _loadProfile(reloadPhoto: false);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                  size: 28,
                ),
                title: const Text(
                  'Escolher da galeria',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromGallery();
                },
              ),
              if (_fotoPath != null && _fotoPath!.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: AppColors.error,
                    size: 28,
                  ),
                  title: const Text(
                    'Remover foto de perfil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _removerFotoPerfil();
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removerFotoPerfil() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('idoso_foto_path');

      if (mounted) {
        setState(() {
          _fotoPath = null;
        });
      }

      if (_useFirebase) {
        final idosoId = await SessionRoleService.getActiveIdosoId();

        // Atualiza Firestore para remover a referência da foto
        try {
          await FirebaseFirestore.instance
              .collection('idosos')
              .doc(idosoId)
              .set({'fotoPath': FieldValue.delete()}, SetOptions(merge: true));
          await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(idosoId)
              .set({'fotoPath': FieldValue.delete()}, SetOptions(merge: true));
        } catch (firestoreError) {
          debugPrint('Erro ao remover URL do Firestore: $firestoreError');
        }

        // Tenta deletar a foto do Firebase Storage
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_photos')
              .child('$idosoId.jpg');
          await ref.delete();
        } catch (storageError) {
          // Ignora se o arquivo já não existir
          debugPrint(
            'Erro ao excluir arquivo físico no Storage: $storageError',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil removida com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover foto de perfil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    XFile? image;
    try {
      final picker = ImagePicker();
      image = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      debugPrint('ImagePicker não suportado neste dispositivo: $e');
      _showSimulatedGalleryPicker();
      return;
    }

    final selectedImage = image;
    if (selectedImage != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('idoso_foto_path', selectedImage.path);

        setState(() {
          _fotoPath = selectedImage.path;
        });

        // Mostra o SnackBar instantaneamente para feedback imediato
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil atualizada!')),
          );
        }

        if (_useFirebase) {
          final idosoId = await SessionRoleService.getActiveIdosoId();

          // Executa o upload e salvamento no Firebase em background
          Future(() async {
            try {
              final file = File(selectedImage.path);
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('profile_photos')
                  .child('$idosoId.jpg');
              final uploadTask = ref.putFile(file);
              final snapshot = await uploadTask;
              final downloadUrl = await snapshot.ref.getDownloadURL();

              await FirebaseFirestore.instance
                  .collection('idosos')
                  .doc(idosoId)
                  .set({'fotoPath': downloadUrl}, SetOptions(merge: true));
              await FirebaseFirestore.instance
                  .collection('idoso_perfil')
                  .doc(idosoId)
                  .set({'fotoPath': downloadUrl}, SetOptions(merge: true));
              debugPrint(
                'Foto da galeria sincronizada no Firebase em background com sucesso!',
              );
            } catch (e) {
              debugPrint(
                'Erro ao sincronizar foto de perfil no Firebase em background: $e',
              );
            }
          });
        }

        _loadProfile(reloadPhoto: false);
      } catch (e) {
        debugPrint('Erro local ao salvar foto de perfil: $e');
      }
    }
  }

  void _showSimulatedGalleryPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecionar da Galeria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione uma imagem de perfil para usar:'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => _useMockPhoto('avatar_1'),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.blue[100],
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _useMockPhoto('avatar_2'),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.green[100],
                      child: const Icon(
                        Icons.face,
                        size: 40,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _useMockPhoto('avatar_3'),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.orange[100],
                      child: const Icon(
                        Icons.portrait,
                        size: 40,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _useMockPhoto(String avatarName) async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idoso_foto_path', avatarName);
    setState(() {
      _fotoPath = avatarName;
    });

    if (_useFirebase) {
      final idosoId = await SessionRoleService.getActiveIdosoId();
      await FirebaseFirestore.instance.collection('idosos').doc(idosoId).set({
        'fotoPath': avatarName,
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .set({'fotoPath': avatarName}, SetOptions(merge: true));
    }

    _loadProfile(reloadPhoto: false);
  }
}

class _EditTitleDialog extends StatefulWidget {
  final String initialValue;

  const _EditTitleDialog({required this.initialValue});

  @override
  State<_EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<_EditTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mudar nome do lembrete'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Escreva o novo nome aqui',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('VOLTAR'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('SALVAR'),
        ),
      ],
    );
  }
}
