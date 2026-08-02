import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';
import '../utils/firebase_helper.dart';

class SupervisorRegisterScreen extends StatefulWidget {
  const SupervisorRegisterScreen({super.key});

  @override
  State<SupervisorRegisterScreen> createState() =>
      _SupervisorRegisterScreenState();
}

class _SupervisorRegisterScreenState extends State<SupervisorRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _criarConta() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (_useFirebase) {
      if (name.isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty) {
        _showError('Por favor, preencha todos os campos.');
        return;
      }
      if (password != confirmPassword) {
        _showError('As senhas não coincidem.');
        return;
      }
      if (password.length < 6) {
        _showError('A senha precisa ter pelo menos 6 caracteres.');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final user = credential.user;
        if (user == null) {
          throw StateError('Conta criada sem usuario autenticado.');
        }

        try {
          await user.updateDisplayName(name);
        } catch (_) {}

        await FirebaseFirestore.instance
            .collection('supervisores')
            .doc(user.uid)
            .set({
              'nome': name,
              'email': email,
              'criadoEm': DateTime.now().toIso8601String(),
            });

        await user.sendEmailVerification();

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/registration-success');
      } on FirebaseAuthException catch (e) {
        String msg = 'Erro ao cadastrar.';
        if (e.code == 'email-already-in-use') {
          msg = 'Este e-mail já está sendo utilizado.';
        } else if (e.code == 'invalid-email') {
          msg = 'E-mail inválido.';
        } else if (e.code == 'weak-password') {
          msg = 'A senha informada é muito fraca.';
        }
        _showError(msg);
      } catch (e) {
        _showError('Erro de conexão: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      _showError(
        'Cadastro indisponivel. Verifique a configuracao do Firebase e tente novamente.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Erro de Cadastro',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
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
              const SupervisorHeader(),
              const SizedBox(height: 24),
              const Text(
                'Criar Conta de Cuidador',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preencha os dados para começar a monitorar.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SeniorInputField(
                label: 'Nome Completo',
                placeholder: 'Seu nome',
                prefixIcon: Icons.person,
                controller: _nameController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'E-mail',
                placeholder: 'nome@exemplo.com',
                prefixIcon: Icons.mail,
                controller: _emailController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Senha',
                placeholder: 'Crie uma senha (min. 6 caracteres)',
                prefixIcon: Icons.lock,
                isPassword: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 24),
              SeniorInputField(
                label: 'Confirmar Senha',
                placeholder: 'Repita a senha',
                prefixIcon: Icons.lock,
                isPassword: true,
                controller: _confirmPasswordController,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _criarConta,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryFixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: Text(
                    _isLoading ? 'CADASTRANDO...' : 'CRIAR CONTA',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Já possui conta?',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Fazer login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
    );
  }
}
