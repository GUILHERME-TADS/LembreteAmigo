import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../widgets/index.dart';

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
      if (mounted) {
        setState(() {
          _isAutonomous = (pairedId == 'idoso_autonomo');
        });
      }

      if (_useFirebase) {
        final idosoId = prefs.getString('selected_idoso_id') ?? pairedId ?? 'joao';
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
          if (data['nome']?.toString().isNotEmpty == true) nome = data['nome'] as String;
          if (data['dataNascimento']?.toString().isNotEmpty == true) dataNasc = data['dataNascimento'] as String;
          if (data['telefone']?.toString().isNotEmpty == true) telefone = data['telefone'] as String;
          if (data['endereco']?.toString().isNotEmpty == true) endereco = data['endereco'] as String;
          fotoPath = data['fotoPath'] as String? ?? fotoPath;
          if (data['condicoes'] != null) {
            condicoes = List<String>.from(data['condicoes'] as List);
          }
        }

        if (docPerfil.exists && docPerfil.data() != null) {
          final data = docPerfil.data()!;
          if (data['nome']?.toString().isNotEmpty == true) nome = data['nome'] as String;
          if (data['dataNascimento']?.toString().isNotEmpty == true) dataNasc = data['dataNascimento'] as String;
          if (data['telefone']?.toString().isNotEmpty == true) telefone = data['telefone'] as String;
          if (data['endereco']?.toString().isNotEmpty == true) endereco = data['endereco'] as String;
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
              _nome = (data['nome'] as String?)?.isNotEmpty == true ? data['nome'] as String : 'Não cadastrado';
              _dataNasc = (data['dataNascimento'] as String?)?.isNotEmpty == true ? data['dataNascimento'] as String : 'Não informada';
              _telefone = (data['telefone'] as String?)?.isNotEmpty == true ? data['telefone'] as String : 'Não informado';
              _endereco = (data['endereco'] as String?)?.isNotEmpty == true ? data['endereco'] as String : 'Não informado';
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

  @override
  Widget build(BuildContext context) {
    // Medicamentos reais filtrados de LembreteService
    final medicamentosReais = LembreteService.instance.lembretes
        .where((l) => l.categoria == 'medicacao')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          TTSService.instance.parar(caller: this);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AlexAssistantSheet(),
          );
        },
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: AlexAvatar(size: 48),
        ),
      ),
      body: SafeArea(
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
                          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                        ),
                        const Text('Lembrete Amigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 32),
                          onPressed: () {
                            TTSService.instance.parar(caller: this);
                            TTSService.instance.falar(
                              'Aqui estão as informações pessoais e medicamentos de $_nome.',
                              caller: this,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        TTSService.instance.parar();
                        final result = await Navigator.pushNamed(
                          context,
                          '/take-photo-confirmation',
                          arguments: 'profile_photo',
                        );
                        if (result != null) {
                          _loadProfile();
                        }
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                          image: _fotoPath != null
                              ? DecorationImage(
                                  image: FileImage(File(_fotoPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _fotoPath == null
                            ? const Icon(Icons.person, size: 48, color: AppColors.onPrimaryContainer)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nome,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                    Text(
                      'Data de Nascimento: $_dataNasc',
                      style: const TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
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
                        child: Text('Nenhuma condição registrada.', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _condicoes.map((c) {
                            return _chip(c, AppColors.secondaryContainer, AppColors.onSecondaryContainer);
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _sectionTitle('Medicamentos em Uso (Remédios cadastrados)'),
                    const SizedBox(height: 12),
                    if (medicamentosReais.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: const Text(
                          'Nenhum lembrete de medicamento ativo cadastrado.',
                          style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                        ),
                      )
                    else
                      ...medicamentosReais.map((med) {
                        return _medicationItem(med.titulo, med.horarioFormatado);
                      }),
                     if (_isAutonomous) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            TTSService.instance.parar(caller: this);
                            await Navigator.pushNamed(context, '/elderly-pairing');
                            _loadProfile();
                          },
                          icon: const Icon(Icons.link, size: 28),
                          label: const Text('VINCULAR A UM SUPERVISOR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          TTSService.instance.parar(caller: this);
                          final result = await Navigator.pushNamed(context, '/edit-profile');
                          if (result == true) {
                            _loadProfile();
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('EDITAR DADOS PESSOAIS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryFixed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          TTSService.instance.parar(caller: this);
                          await Navigator.pushNamed(context, '/adjust-task');
                          _loadProfile(); // recarrega se voltar
                        },
                        icon: const Icon(Icons.access_time),
                        label: const Text('AJUSTAR HORÁRIOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          foregroundColor: AppColors.onSurfaceVariant,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppColors.outlineVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 18, color: AppColors.onSurface))),
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
      child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _medicationItem(String name, String schedule) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text(schedule, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}
