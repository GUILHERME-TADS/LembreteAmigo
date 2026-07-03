import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../widgets/index.dart';
import '../widgets/custom_time_picker.dart';
import '../models/lembrete.dart';

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
  List<String> _condicoes = [];
  String? _fotoPath;
  bool _isLoading = true;
  bool _isAutonomous = false;
  bool _largeText = false;
  bool _highContrast = false;
  bool _slowVoice = false;
  bool _largeButtons = false;
  bool _reduceAnimations = false;

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

  Future<void> _loadProfile() async {
    await LembreteService.instance.carregar();
    try {
      final prefs = await SharedPreferences.getInstance();
      final pairedId = prefs.getString('paired_idoso_id');
      final lText = prefs.getBool('accessibility_large_text') ?? false;
      final hContrast = prefs.getBool('accessibility_high_contrast') ?? false;
      final sVoice = prefs.getBool('accessibility_slow_voice') ?? false;
      final lButtons = prefs.getBool('accessibility_large_buttons') ?? false;
      final rAnims = prefs.getBool('accessibility_reduce_animations') ?? false;

      if (mounted) {
        setState(() {
          _isAutonomous = (pairedId == 'idoso_autonomo');
          _largeText = lText;
          _highContrast = hContrast;
          _slowVoice = sVoice;
          _largeButtons = lButtons;
          _reduceAnimations = rAnims;
        });
      }

      if (_useFirebase) {
        final idosoId =
            prefs.getString('selected_idoso_id') ?? pairedId ?? 'joao';
        final docPerfil = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        final docIdoso = await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .get();

        final localFoto = prefs.getString('idoso_foto_path');

        String nome = 'Não cadastrado';
        String dataNasc = 'Não informada';
        String telefone = 'Não informado';
        String endereco = 'Não informado';
        List<String> condicoes = [];
        String? fotoPath = localFoto;

        if (docIdoso.exists && docIdoso.data() != null) {
          final data = docIdoso.data()!;
          if (data['nome']?.toString().isNotEmpty == true)
            nome = data['nome'] as String;
          if (data['dataNascimento']?.toString().isNotEmpty == true)
            dataNasc = data['dataNascimento'] as String;
          if (data['telefone']?.toString().isNotEmpty == true)
            telefone = data['telefone'] as String;
          if (data['endereco']?.toString().isNotEmpty == true)
            endereco = data['endereco'] as String;
          fotoPath = data['fotoPath'] as String? ?? fotoPath;
          if (data['condicoes'] != null) {
            condicoes = List<String>.from(data['condicoes'] as List);
          }
        }

        if (docPerfil.exists && docPerfil.data() != null) {
          final data = docPerfil.data()!;
          if (data['nome']?.toString().isNotEmpty == true)
            nome = data['nome'] as String;
          if (data['dataNascimento']?.toString().isNotEmpty == true)
            dataNasc = data['dataNascimento'] as String;
          if (data['telefone']?.toString().isNotEmpty == true)
            telefone = data['telefone'] as String;
          if (data['endereco']?.toString().isNotEmpty == true)
            endereco = data['endereco'] as String;
          fotoPath = data['fotoPath'] as String? ?? fotoPath;
          if (data['condicoes'] != null) {
            condicoes = List<String>.from(data['condicoes'] as List);
          }
        }

        if (mounted) {
          setState(() {
            _nome = nome;
            _dataNasc = dataNasc;
            _telefone = telefone;
            _endereco = endereco;
            _condicoes = condicoes;
            _fotoPath = fotoPath;
            _isLoading = false;
          });
        }
        return;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('idoso_perfil');
        final localFoto = prefs.getString('idoso_foto_path');
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _nome = (data['nome'] as String?)?.isNotEmpty == true
                  ? data['nome'] as String
                  : 'Não cadastrado';
              _dataNasc =
                  (data['dataNascimento'] as String?)?.isNotEmpty == true
                  ? data['dataNascimento'] as String
                  : 'Não informada';
              _telefone = (data['telefone'] as String?)?.isNotEmpty == true
                  ? data['telefone'] as String
                  : 'Não informado';
              _endereco = (data['endereco'] as String?)?.isNotEmpty == true
                  ? data['endereco'] as String
                  : 'Não informado';
              _condicoes = List<String>.from(data['condicoes'] as List? ?? []);
              _fotoPath = localFoto;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAccessibilitySetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key == 'accessibility_slow_voice') {
      await TTSService.instance.setSpeechRate(value ? 0.38 : 0.5);
    }
    setState(() {
      if (key == 'accessibility_large_text') _largeText = value;
      if (key == 'accessibility_high_contrast') _highContrast = value;
      if (key == 'accessibility_slow_voice') _slowVoice = value;
      if (key == 'accessibility_large_buttons') _largeButtons = value;
      if (key == 'accessibility_reduce_animations') _reduceAnimations = value;
    });
  }

  Future<void> _showEditDeleteDialog(Lembrete lembrete) async {
    TTSService.instance.parar(caller: this);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              // Button 1: Mudar Horário
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _adjustTime(lembrete);
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
                      side: const BorderSide(color: AppColors.secondary, width: 2),
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
                    _editTitle(lembrete);
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
                      side: const BorderSide(color: AppColors.outlineVariant, width: 2),
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
                    _deleteReminder(lembrete);
                  },
                  icon: const Icon(Icons.delete, size: 28),
                  label: const Text(
                    'EXCLUIR LEMBRETE',
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
                    'CANCELAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
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
    await LembreteService.instance.atualizarHorario(
      lembrete.id,
      picked.hour,
      picked.minute,
    );
    await _loadProfile();
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
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
    final controller = TextEditingController(text: lembrete.titulo);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar nome do lembrete'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('SALVAR'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.isEmpty || result == lembrete.titulo) return;
    await LembreteService.instance.atualizarTitulo(lembrete.id, result);
    await _loadProfile();
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
          title: const Text('Excluir lembrete?'),
          content: Text(
            'Deseja excluir "${lembrete.titulo}"? Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
              ),
              child: const Text('EXCLUIR'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await LembreteService.instance.remover(lembrete.id);
    await _loadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lembrete excluído.')));
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  TTSService.instance.parar(caller: this);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'Lembrete Amigo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const MeExplicaButton(
                            textoExplicacao: 'Olá! Esta é a tela com as suas informações. Aqui você vê o seu nome e telefone. Para mudar sua foto, aperte em cima do círculo da foto. Para mudar seu nome ou se conectar com um ajudante, use os botões da lista abaixo.',
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _selectProfilePhotoOptions,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                                image: _fotoPath != null && !_fotoPath!.startsWith('avatar_') && File(_fotoPath!).existsSync()
                                    ? DecorationImage(
                                        image: FileImage(File(_fotoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _fotoPath == null || _fotoPath!.startsWith('avatar_')
                                  ? _buildAvatarIconChild()
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _selectProfilePhotoOptions,
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text(
                              'Editar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.onPrimaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _nome,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Data de Nascimento: $_dataNasc',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _sectionTitle('Informações de Contato'),
                          const SizedBox(height: 12),
                          _infoRow(Icons.phone, _telefone),
                          _infoRow(Icons.location_on, _endereco),
                          const SizedBox(height: 24),
                          _sectionTitle('Condições de Saúde'),
                          const SizedBox(height: 12),
                          if (_condicoes.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Nenhuma condição registrada.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _condicoes.map((c) {
                                  return _chip(
                                    c,
                                    AppColors.secondaryContainer,
                                    AppColors.onSecondaryContainer,
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _sectionTitle('Medicamentos em Uso (Remédios cadastrados)'),
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
                              border: Border.all(color: AppColors.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                if (_isAutonomous) ...[
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
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
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
                                      backgroundColor: AppColors.secondaryContainer,
                                      foregroundColor: AppColors.onSecondaryFixed,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _medicationItem(Lembrete med) {
    final color = AppColors.medicationsColor;
    return InkWell(
      onTap: () => _showEditDeleteDialog(med),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 8,
                  color: color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.medication, color: color, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                med.titulo,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                med.horarioFormatado,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.outline),
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

  Widget _reminderItem(Lembrete lembrete) {
    IconData icon = Icons.notifications;
    Color color = AppColors.customColor;
    switch (lembrete.categoria) {
      case 'refeicoes':
        icon = Icons.restaurant;
        color = AppColors.mealsColor;
        break;
      case 'hidratacao':
        icon = Icons.water_drop;
        color = AppColors.voiceFeedbackBlue;
        break;
      case 'exercicio':
        icon = Icons.directions_walk;
        color = const Color(0xFF2E7D32);
        break;
    }

    return InkWell(
      onTap: () => _showEditDeleteDialog(lembrete),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 8,
                  color: color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lembrete.titulo,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lembrete.horarioFormatado,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.outline),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary, size: 28),
                title: const Text('Tirar foto (Câmera)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.pushNamed(
                    context,
                    '/take-photo-confirmation',
                    arguments: 'profile_photo',
                  );
                  if (result != null) {
                    _loadProfile();
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary, size: 28),
                title: const Text('Escolher da galeria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromGallery();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('idoso_foto_path', image.path);
        
        if (_useFirebase) {
          final pairedId = prefs.getString('paired_idoso_id') ?? 'joao';
          final idosoId = prefs.getString('selected_idoso_id') ?? pairedId;
          await FirebaseFirestore.instance.collection('idosos').doc(idosoId).update({
            'fotoPath': image.path,
          });
          await FirebaseFirestore.instance.collection('idoso_perfil').doc(idosoId).set({
            'fotoPath': image.path,
          }, SetOptions(merge: true));
        }
        
        _loadProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil atualizada!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao selecionar foto da galeria: $e');
      _showSimulatedGalleryPicker();
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
                      child: const Icon(Icons.person, size: 40, color: Colors.blue),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _useMockPhoto('avatar_2'),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.green[100],
                      child: const Icon(Icons.face, size: 40, color: Colors.green),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _useMockPhoto('avatar_3'),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.orange[100],
                      child: const Icon(Icons.portrait, size: 40, color: Colors.orange),
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
    
    if (_useFirebase) {
      final pairedId = prefs.getString('paired_idoso_id') ?? 'joao';
      final idosoId = prefs.getString('selected_idoso_id') ?? pairedId;
      await FirebaseFirestore.instance.collection('idosos').doc(idosoId).update({
        'fotoPath': avatarName,
      });
      await FirebaseFirestore.instance.collection('idoso_perfil').doc(idosoId).set({
        'fotoPath': avatarName,
      }, SetOptions(merge: true));
    }
    
    _loadProfile();
  }
}
