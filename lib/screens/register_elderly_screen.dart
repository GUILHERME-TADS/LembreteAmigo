import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/senior_button.dart';

class RegisterElderlyScreen extends StatefulWidget {
  const RegisterElderlyScreen({super.key});

  @override
  State<RegisterElderlyScreen> createState() => _RegisterElderlyScreenState();
}

class _RegisterElderlyScreenState extends State<RegisterElderlyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  final List<String> _selectedConditions = [];
  bool _isLoading = false;

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _codeController.dispose();
    super.dispose();
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

  void _cadastrar() async {
    final nome = _nameController.text.trim();
    final dataNasc = _birthDateController.text.trim();
    final telefone = _phoneController.text.trim();
    final endereco = _addressController.text.trim();
    final code = _codeController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o nome completo do idoso.')),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o código de 6 dígitos exibido no celular do idoso.')),
      );
      return;
    }

    if (!_useFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O Firebase não está ativo. Conecte-se à internet para realizar o vínculo.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .where('pairingCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido ou já utilizado. Verifique no celular do idoso.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final doc = query.docs.first;
      final docId = doc.id;

      final data = doc.data();
      final expiresStr = data['pairingCodeExpires'] as String?;
      if (expiresStr != null) {
        final expires = DateTime.parse(expiresStr);
        if (DateTime.now().isAfter(expires)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este código expirou. Gere um novo código no celular do idoso.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final updateData = {
        'nome': nome,
        'dataNascimento': dataNasc,
        'telefone': telefone,
        'endereco': endereco,
        'condicoes': _selectedConditions,
        'supervisorId': FirebaseAuth.instance.currentUser?.uid,
        'status': 'active',
      };

      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(docId)
          .update(updateData);

      await FirebaseFirestore.instance
          .collection('idosos')
          .doc(docId)
          .set(updateData, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_idoso_id', docId);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Vínculo Realizado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'O dispositivo do idoso foi vinculado com sucesso ao seu painel de controle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Concluir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cadastro: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Cadastrar Novo Idoso',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adicione um novo idoso para começar a monitorar.',
                style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              SeniorInputField(
                label: 'Nome Completo',
                placeholder: 'Nome do idoso',
                prefixIcon: Icons.person,
                controller: _nameController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Data de Nascimento',
                placeholder: 'DD/MM/AAAA',
                prefixIcon: Icons.calendar_today,
                controller: _birthDateController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Telefone de Contato',
                placeholder: '(11) 99999-9999',
                prefixIcon: Icons.phone,
                controller: _phoneController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Endereço',
                placeholder: 'Rua, número, bairro',
                prefixIcon: Icons.location_on,
                controller: _addressController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Código de Conexão do Idoso (6 dígitos)',
                placeholder: 'Código que aparece na tela do idoso',
                prefixIcon: Icons.vpn_key,
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'CONDIÇÕES DE SAÚDE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _cadastrar,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryFixed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: Text(
                    _isLoading ? 'CADASTRANDO...' : 'CADASTRAR',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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

  Widget _healthChip(String label) {
    final selected = _selectedConditions.contains(label);
    return GestureDetector(
      onTap: () => _toggleCondition(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryContainer : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onSecondaryContainer : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
