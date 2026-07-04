import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/senior_button.dart';
import '../widgets/volume_warning_banner.dart';
import '../widgets/me_explica_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  final List<String> _selectedConditions = [];
  bool _isLoading = true;
  bool _isSaving = false;

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
    _loadCurrentProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Tela de edição de perfil. Modifique os campos que desejar e clique em salvar.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String nome = '';
      String dataNasc = '';
      String telefone = '';
      String endereco = '';
      List<String> condicoes = [];

      // 1. Sempre carrega os dados locais como fallback/inicialização
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        nome = data['nome'] as String? ?? nome;
        dataNasc = data['dataNascimento'] as String? ?? dataNasc;
        telefone = data['telefone'] as String? ?? telefone;
        endereco = data['endereco'] as String? ?? endereco;
        if (data['condicoes'] != null) {
          condicoes = List<String>.from(data['condicoes'] as List);
        }
      }

      // 2. Se o Firebase estiver ativo, tenta sincronizar e atualizar com o banco remoto
      if (_useFirebase) {
        try {
          final idosoId = prefs.getString('selected_idoso_id') ?? prefs.getString('paired_idoso_id') ?? 'joao';
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
            nome = data['nome'] as String? ?? nome;
            dataNasc = data['dataNascimento'] as String? ?? dataNasc;
            telefone = data['telefone'] as String? ?? telefone;
            endereco = data['endereco'] as String? ?? endereco;
            if (data['condicoes'] != null) {
              condicoes = List<String>.from(data['condicoes'] as List);
            }
          }

          if (docPerfil.exists && docPerfil.data() != null) {
            final data = docPerfil.data()!;
            nome = data['nome'] as String? ?? nome;
            dataNasc = data['dataNascimento'] as String? ?? dataNasc;
            telefone = data['telefone'] as String? ?? telefone;
            endereco = data['endereco'] as String? ?? endereco;
            if (data['condicoes'] != null) {
              condicoes = List<String>.from(data['condicoes'] as List);
            }
          }
        } catch (firebaseError) {
          debugPrint('Erro ao carregar perfil do Firebase (usando dados locais): $firebaseError');
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text = nome;
          _birthDateController.text = dataNasc;
          _phoneController.text = telefone;
          _addressController.text = endereco;
          _selectedConditions.clear();
          _selectedConditions.addAll(condicoes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil para edição: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (_selectedConditions.contains(condition)) {
        _selectedConditions.remove(condition);
      } else {
        _selectedConditions.add(condition);
      }
    });
  }

  Future<void> _salvar() async {
    final nome = _nameController.text.trim();
    final dataNasc = _birthDateController.text.trim();
    final telefone = _phoneController.text.trim();
    final endereco = _addressController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o nome completo do idoso.')),
      );
      TTSService.instance.falar('Por favor, digite o nome completo do idoso.', caller: this);
      return;
    }

    TTSService.instance.falar('Salvando suas informações, por favor aguarde...', caller: this);
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final idosoId = prefs.getString('selected_idoso_id') ?? prefs.getString('paired_idoso_id') ?? 'joao';

    final perfil = {
      'nome': nome,
      'dataNascimento': dataNasc,
      'telefone': telefone,
      'endereco': endereco,
      'condicoes': _selectedConditions,
      'status': 'active',
    };

    try {
      // Salva localmente primeiro
      await prefs.setString('idoso_perfil', jsonEncode(perfil));

      // Salva no Firebase se estiver ativo em background
      if (_useFirebase) {
        Future(() async {
          try {
            await FirebaseFirestore.instance
                .collection('idoso_perfil')
                .doc(idosoId)
                .set(perfil, SetOptions(merge: true));
            await FirebaseFirestore.instance
                .collection('idosos')
                .doc(idosoId)
                .set(perfil, SetOptions(merge: true));
            debugPrint('Perfil sincronizado com o Firebase em background com sucesso!');
          } catch (firebaseError) {
            debugPrint('Erro ao sincronizar perfil no Firebase em background: $firebaseError');
          }
        });
      }

      TTSService.instance.parar(caller: this);
      TTSService.instance.falar('Perfil atualizado com sucesso!', caller: this);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar alterações do perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed: () {
                                    TTSService.instance.parar(caller: this);
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                                ),
                              ),
                              const Text(
                                'Editar Perfil',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                           const SizedBox(height: 12),
                           const Center(
                             child: MeExplicaButton(
                               textoExplicacao: 'Olá! Aqui você altera as suas informações, como seu nome completo, sua data de nascimento, seu telefone e seu endereço. Quando terminar, aperte o botão salvar perfil no final.',
                             ),
                           ),
                           const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Nome Completo',
                            placeholder: 'Nome do idoso',
                            prefixIcon: Icons.person,
                            controller: _nameController,
                            onTapAudio: () => TTSService.instance.falar('Digite o seu nome completo nesta caixa.', caller: this),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Data de Nascimento',
                            placeholder: 'DD/MM/AAAA',
                            prefixIcon: Icons.calendar_today,
                            controller: _birthDateController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [DateInputFormatter()],
                            onTapAudio: () => TTSService.instance.falar('Digite o dia, o mês e o ano em que você nasceu.', caller: this),
                          ),
                          const SizedBox(height: 24),
                          SeniorInputField(
                            label: 'Telefone de Contato',
                            placeholder: '(11) 99999-9999',
                            prefixIcon: Icons.phone,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            onTapAudio: () => TTSService.instance.falar('Digite o número do seu celular com o D D D.', caller: this),
                          ),
                    const SizedBox(height: 24),
                    SeniorInputField(
                      label: 'Endereço',
                      placeholder: 'Rua, número, bairro',
                      prefixIcon: Icons.location_on,
                      controller: _addressController,
                      onTapAudio: () => TTSService.instance.falar('Digite o nome da sua rua e o número da sua casa.', caller: this),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CONDIÇÕES DE SAÚDE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _healthChip('Hipertensão'),
                        _healthChip('Diabetes'),
                        _healthChip('Colesterol'),
                        _healthChip('Outros'),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _salvar,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryFixed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        label: Text(
                          _isSaving ? 'SALVANDO...' : 'SALVAR PERFIL',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
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

  Widget _healthChip(String label) {
    final selected = _selectedConditions.contains(label);
    IconData icon = Icons.health_and_safety;
    if (label.contains('Diabetes')) {
      icon = Icons.bloodtype;
    } else if (label.contains('Hipertensão')) {
      icon = Icons.favorite;
    } else if (label.contains('Colesterol')) {
      icon = Icons.speed;
    } else if (label.contains('Outros')) {
      icon = Icons.add_moderator;
    }

    return GestureDetector(
      onTap: () {
        TTSService.instance.falar('Condição de saúde: $label. ${selected ? "Removida" : "Adicionada"}', caller: this);
        _toggleCondition(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryContainer : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.onSecondaryContainer : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.length < oldValue.text.length) {
      return newValue;
    }
    final clean = text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      if (i < 8) {
        buffer.write(clean[i]);
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.length < oldValue.text.length) {
      return newValue;
    }
    final clean = text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 0) {
        buffer.write('(');
      }
      if (i == 2) {
        buffer.write(') ');
      }
      if (i == 7 && clean.length > 10) {
        buffer.write('-');
      } else if (i == 6 && clean.length <= 10) {
        buffer.write('-');
      }
      if (i < 11) {
        buffer.write(clean[i]);
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
