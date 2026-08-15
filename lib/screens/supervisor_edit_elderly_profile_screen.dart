import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/secure_cache_service.dart';
import '../theme/app_theme.dart';
import '../utils/firebase_helper.dart';

class SupervisorEditElderlyProfileScreen extends StatefulWidget {
  const SupervisorEditElderlyProfileScreen({super.key});

  @override
  State<SupervisorEditElderlyProfileScreen> createState() =>
      _SupervisorEditElderlyProfileScreenState();
}

class _SupervisorEditElderlyProfileScreenState
    extends State<SupervisorEditElderlyProfileScreen> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ambulancePhoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _idosoId;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _ambulancePhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await SessionRoleService.load();
    final idosoId = await SessionRoleService.getActiveIdosoId();
    final isConnected = await SessionRoleService.isSupervisorConnected();

    if (!isConnected || SessionRoleService.isLocalOnlyIdosoId(idosoId)) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conecte um idoso antes de editar os dados.'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pop(context);
      return;
    }

    _idosoId = idosoId;
    final data = <String, dynamic>{};
    final localJson = await SecureCacheService.instance.readElderlyProfile();
    if (localJson != null) {
      try {
        data.addAll(jsonDecode(localJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    if (_useFirebase) {
      try {
        data.addAll(
          await ElderlyProfileRepository.instance.getMergedData(idosoId),
        );
      } catch (e) {
        debugPrint('Erro ao carregar dados do idoso para supervisor: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _nameController.text = data['nome'] as String? ?? '';
      _birthDateController.text = data['dataNascimento'] as String? ?? '';
      _phoneController.text = data['telefone'] as String? ?? '';
      _ambulancePhoneController.text =
          data['ambulancia_telefone'] as String? ?? '';
      _addressController.text = data['endereco'] as String? ?? '';
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final idosoId = _idosoId;
    if (idosoId == null) return;

    final nome = _nameController.text.trim();
    final dataNascimento = _birthDateController.text.trim();
    final telefone = _phoneController.text.trim();
    final ambulancia = _ambulancePhoneController.text.trim();
    final endereco = _addressController.text.trim();

    if (nome.isEmpty) {
      _showError('Informe o nome do idoso.');
      return;
    }

    final phoneRegex = RegExp(r'^(\(?\d{2}\)?\s?)?\d{4,5}\-?\d{4}$');
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (dataNascimento.isNotEmpty && !dateRegex.hasMatch(dataNascimento)) {
      _showError('Use o formato DD/MM/AAAA para a data de nascimento.');
      return;
    }
    if (telefone.isNotEmpty && !phoneRegex.hasMatch(telefone)) {
      _showError('Informe um telefone valido.');
      return;
    }
    if (ambulancia.isNotEmpty && !phoneRegex.hasMatch(ambulancia)) {
      _showError('Informe um telefone de ambulancia valido.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final profile = <String, dynamic>{};
      final localJson = await SecureCacheService.instance.readElderlyProfile();
      if (localJson != null) {
        try {
          profile.addAll(jsonDecode(localJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      if (_useFirebase) {
        final perfilDoc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (perfilDoc.data() != null) profile.addAll(perfilDoc.data()!);
      }

      final sanitized = ElderlyProfileRepository.instance.sanitize(profile)
        ..['nome'] = nome
        ..['dataNascimento'] = dataNascimento
        ..['telefone'] = telefone
        ..['ambulancia_telefone'] = ambulancia
        ..['endereco'] = endereco;

      await SecureCacheService.instance.writeElderlyProfile(
        jsonEncode(sanitized),
      );

      if (_useFirebase) {
        await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .set(sanitized, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('idosos')
            .doc(idosoId)
            .set(sanitized, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados do idoso atualizados.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar dados do idoso pelo supervisor: $e');
      if (mounted) _showError('Nao foi possivel salvar os dados.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados do Idoso')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _field(
                    controller: _nameController,
                    label: 'Nome completo',
                    icon: Icons.person,
                  ),
                  _field(
                    controller: _birthDateController,
                    label: 'Data de nascimento',
                    hint: 'DD/MM/AAAA',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateInputFormatter()],
                  ),
                  _field(
                    controller: _phoneController,
                    label: 'Telefone de contato',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                  ),
                  _field(
                    controller: _ambulancePhoneController,
                    label: 'Telefone da ambulancia',
                    icon: Icons.local_hospital,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneInputFormatter()],
                  ),
                  _field(
                    controller: _addressController,
                    label: 'Endereco',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSaving ? 'Salvando...' : 'Salvar dados',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(limited[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
