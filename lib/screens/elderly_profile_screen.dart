import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../services/session_role_service.dart';
import '../services/offline_sync_service.dart';
import '../services/durable_media_service.dart';
import '../services/secure_cache_service.dart';
import '../widgets/index.dart';
import '../widgets/custom_time_picker.dart';
import '../models/lembrete.dart';
import '../utils/period_helper.dart';
import '../utils/firebase_helper.dart';

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

  bool get _useFirebase => FirebaseHelper.isInitialized;

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
      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
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
      if (_useFirebase &&
          await SessionRoleService.canSyncElderlyPrivateData()) {
        try {
          final idosoId = await SessionRoleService.getActiveIdosoId();
          if (SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
            if (mounted) {
              setState(() {
                _isConnectionActive = false;
              });
            }
          } else {
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
              final jsonStr = await SecureCacheService.instance
                  .readElderlyProfile();
              if (jsonStr != null) {
                try {
                  final localData = jsonDecode(jsonStr) as Map<String, dynamic>;
                  localData['status'] = firestoreStatus;
                  localData['supervisorId'] = firestoreSupervisorId;
                  await SecureCacheService.instance.writeElderlyProfile(
                    jsonEncode(localData),
                  );
                } catch (_) {}
              }

              if (mounted) {
                setState(() {
                  _isConnectionActive = firestoreStatus == 'active';
                });
              }
              if (firestoreStatus == 'active' &&
                  firestoreSupervisorId != null) {
                await prefs.setBool('elderly_autonomous_mode', false);
              }
            }

            if (reloadPhoto) {
              // Smart local-first photo path sync
              bool isLocalFile =
                  localFoto != null && !localFoto.startsWith('avatar_');
              bool localFileExists =
                  isLocalFile && File(localFoto).existsSync();

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
        title: const Text(
          'Desconectar Cuidador?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        content: const Text(
          'Deseja mesmo desconectar o celular do seu cuidador? Depois disso, você usará o aplicativo sozinho.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'NÃO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SIM, DESCONECTAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
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
      if (!SessionRoleService.isLocalOnlyIdosoId(docId) && _useFirebase) {
        try {
          await FirebaseFunctions.instance.httpsCallable('unlinkElderly').call({
            'elderlyId': docId,
          });
        } catch (error) {
          syncError = error;
          debugPrint('Erro ao sincronizar desvínculo na nuvem: $error');
        }
      }
      await SessionRoleService.ensureStableElderlyId();
      await prefs.setBool('elderly_autonomous_mode', true);

      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      if (jsonStr != null) {
        final Map<String, dynamic> data =
            jsonDecode(jsonStr) as Map<String, dynamic>;
        data['status'] = 'pending';
        data['supervisorId'] = null;
        await SecureCacheService.instance.writeElderlyProfile(jsonEncode(data));
      }

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = syncError == null
          ? 'Pronto. O cuidador foi desconectado.'
          : 'O cuidador foi desconectado neste celular. Quando a internet voltar, vou terminar de avisar o outro celular.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      await TTSService.instance.falar(message, caller: this);
      await _loadProfile();
    } catch (e) {
      debugPrint('Erro ao desvincular: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não consegui desconectar o cuidador. Tente de novo.',
            ),
          ),
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
        content: Text('Pronto. O horário foi trocado.'),
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
      builder: (context) =>
          ElderlyEditTitleDialog(initialValue: lembrete.titulo),
    );

    if (result == null || result.isEmpty || result == lembrete.titulo) return;
    LembreteService.instance.atualizarTitulo(lembrete.id, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pronto. O nome foi trocado.')),
    );
  }

  Future<void> _deleteReminder(Lembrete lembrete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ElderlyDeleteReminderDialog(lembrete: lembrete),
    );

    if (confirm != true) return;
    LembreteService.instance.remover(lembrete.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lembrete apagado.')));
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: AppColors.surface),
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
                'Meus Dados',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(
            width: 48,
          ), // Mantém o equilíbrio visual com o botão de voltar no lado oposto
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
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta é a tela com os seus dados. Aqui você vê seu nome, telefone, medicações e lembretes. Para mudar seus dados, aperte o botão amarelo. Para arrumar a minha voz, aperte o botão laranja.',
      ),
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _nome.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.volume_up,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Ouvir nome',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                          _sectionTitle('Telefone e Endereço'),
                          const SizedBox(height: 12),
                          _infoRow(Icons.phone, 'Meu telefone', _telefone),
                          _infoRow(
                            Icons.location_on,
                            'Meu endereço',
                            _endereco,
                          ),
                          _sectionTitle('Meus Remédios'),
                          const SizedBox(height: 12),
                          if (medicamentosReais.isEmpty)
                            _buildEmptyState(
                              'Nenhum remédio para lembrar agora.',
                              Icons.medication_outlined,
                            )
                          else
                            ...medicamentosReais.map((med) {
                              return _medicationItem(med);
                            }),
                          const SizedBox(height: 24),
                          _sectionTitle('Lembretes do Dia'),
                          const SizedBox(height: 12),
                          if (lembretesReais.isEmpty)
                            _buildEmptyState(
                              'Nenhum outro lembrete para agora.',
                              Icons.notifications_off_outlined,
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
                                              'CONECTAR COM CUIDADOR',
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
                                      onPressed: () =>
                                          _desvincularAjudante(context),
                                      icon: const Icon(
                                        Icons.link_off,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'DESCONECTAR CUIDADOR',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                      backgroundColor: AppColors.primaryFixed,
                                      foregroundColor: AppColors.onPrimaryFixed,
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
                                            'VELOCIDADE DA VOZ',
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
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: const Text(
                                            'Sair do Modo Idoso?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: const Text(
                                            'Deseja voltar para a tela de entrada? Seus dados e lembretes continuarão salvos.',
                                            style: TextStyle(fontSize: 18),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text(
                                                'NÃO',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'SIM, SAIR',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await SessionRoleService.exitElderlyModeOnly();
                                        await LembreteService.instance.reset();
                                        if (context.mounted) {
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            '/',
                                            (route) => false,
                                          );
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.onSurface,
                                      side: const BorderSide(
                                        color: AppColors.outlineVariant,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Ouvir',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
                              final spoken =
                                  PeriodHelper.getSpokenTimeWithPrepositionFromStr(
                                    med.horarioFormatado,
                                  );
                              TTSService.instance.falar(
                                'Remédio: ${med.titulo} $spoken',
                                caller: this,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volume_up,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ouvir',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
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
        catName = 'comida';
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
                              final spoken =
                                  PeriodHelper.getSpokenTimeWithPrepositionFromStr(
                                    lembrete.horarioFormatado,
                                  );
                              TTSService.instance.falar(
                                'Lembrete de $catName: ${lembrete.titulo} $spoken',
                                caller: this,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volume_up,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ouvir',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
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
                'Minha foto',
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
                  'Tirar foto agora',
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
                  'Escolher foto do celular',
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
                    'Apagar minha foto',
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

      if (_useFirebase &&
          await SessionRoleService.canSyncElderlyPrivateData()) {
        final idosoId = await SessionRoleService.getActiveIdosoId();

        // Atualiza Firestore para remover a referência da foto
        await OfflineSyncService.instance.setOrQueue('idosos', idosoId, {
          'fotoPath': null,
        });
        await OfflineSyncService.instance.setOrQueue('idoso_perfil', idosoId, {
          'fotoPath': null,
        });

        // Tenta deletar a foto do Firebase Storage
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('perfis')
              .child(idosoId)
              .child('profile.jpg');
          await ref.delete();
        } catch (storageError) {
          // Ignora se o arquivo já não existir
          debugPrint(
            'Erro ao excluir arquivo físico no Storage: $storageError',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sua foto foi apagada.')));
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
        final durablePath = await DurableMediaService.instance.preserve(
          selectedImage.path,
          prefix: 'profile_photo',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('idoso_foto_path', durablePath);

        setState(() {
          _fotoPath = durablePath;
        });

        // Mostra o SnackBar instantaneamente para feedback imediato
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sua foto foi trocada.')),
          );
        }

        if (_useFirebase) {
          final idosoId = await SessionRoleService.getActiveIdosoId();

          await OfflineSyncService.instance.setOrQueue('idosos', idosoId, {
            'fotoPath': durablePath,
          });
          await OfflineSyncService.instance.setOrQueue(
            'idoso_perfil',
            idosoId,
            {'fotoPath': durablePath},
          );
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
              const Text('Escolha uma foto para usar:'),
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
      await OfflineSyncService.instance.setOrQueue('idosos', idosoId, {
        'fotoPath': avatarName,
      });
      await OfflineSyncService.instance.setOrQueue('idoso_perfil', idosoId, {
        'fotoPath': avatarName,
      });
    }

    _loadProfile(reloadPhoto: false);
  }
}

class ElderlyEditTitleDialog extends StatefulWidget {
  final String initialValue;

  const ElderlyEditTitleDialog({super.key, required this.initialValue});

  @override
  State<ElderlyEditTitleDialog> createState() => _ElderlyEditTitleDialogState();
}

class _ElderlyEditTitleDialogState extends State<ElderlyEditTitleDialog> {
  late final TextEditingController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ditarNome() async {
    await TTSService.instance.parar(caller: this);
    if (_isListening) {
      await _speech.stop();
      SystemSound.play(SystemSoundType.click);
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('Erro no ditado: ${error.errorMsg}');
          if (mounted) {
            if (_isListening) {
              SystemSound.play(SystemSoundType.click);
            }
            setState(() => _isListening = false);
          }
        },
        onStatus: (status) {
          final isDone =
              status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus;
          if (isDone && mounted && _isListening) {
            SystemSound.play(SystemSoundType.click);
            setState(() => _isListening = false);
          }
        },
      );

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não consegui ouvir sua voz neste celular.'),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isListening = true);
      SystemSound.play(SystemSoundType.click);

      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
            if (result.finalResult) {
              if (_isListening) {
                SystemSound.play(SystemSoundType.click);
              }
              setState(() => _isListening = false);
              if (_controller.text.isNotEmpty) {
                TTSService.instance.falar(
                  'Anotado: ${_controller.text}',
                  caller: this,
                );
              }
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          listenMode: stt.ListenMode.dictation,
          localeId: 'pt_BR',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao iniciar ditado: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Mudar nome do lembrete',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SeniorInputField(
              label: 'Novo Nome',
              placeholder: 'Escreva ou dite o novo nome',
              prefixIcon: Icons.edit,
              controller: _controller,
              onTapAudio: () => TTSService.instance.falar(
                'Digite o novo nome do lembrete ou aperte no botão verde de ditar para falar o nome.',
                caller: this,
              ),
              onTapMic: _ditarNome,
              isListening: _isListening,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            TTSService.instance.parar(caller: this);
            _speech.stop();
            Navigator.pop(context);
          },
          child: const Text(
            'VOLTAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            TTSService.instance.parar(caller: this);
            _speech.stop();
            Navigator.pop(context, _controller.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'SALVAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class ElderlyDeleteReminderDialog extends StatefulWidget {
  final Lembrete lembrete;

  const ElderlyDeleteReminderDialog({super.key, required this.lembrete});

  @override
  State<ElderlyDeleteReminderDialog> createState() =>
      _ElderlyDeleteReminderDialogState();
}

class _ElderlyDeleteReminderDialogState
    extends State<ElderlyDeleteReminderDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _falarExplicacao();
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _falarExplicacao() {
    TTSService.instance.falar(
      'Você quer mesmo apagar o lembrete "${widget.lembrete.titulo}"? Para apagar, aperte o botão vermelho APAGAR. Se não quiser apagar, aperte VOLTAR.',
      caller: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Apagar lembrete?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          // Botão de Ouvir
          GestureDetector(
            onTap: _falarExplicacao,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.volume_up, size: 20, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Ouvir',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Você quer mesmo apagar o lembrete "${widget.lembrete.titulo}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            TTSService.instance.parar(caller: this);
            Navigator.pop(context, false);
          },
          child: const Text(
            'VOLTAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            TTSService.instance.parar(caller: this);
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'APAGAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
