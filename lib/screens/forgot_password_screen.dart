import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';
import '../utils/firebase_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _showSuccess = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SupervisorHeader(),
                    const SizedBox(height: 24),
                    Text(
                      'Recuperar Senha',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Insira seu e-mail de cuidador cadastrado para enviarmos as instruções de redefinição.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SeniorInputField(
                      label: 'E-mail',
                      placeholder: 'nome@exemplo.com',
                      prefixIcon: Icons.mail,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'Verifique se o e-mail inserido é o mesmo utilizado no seu ID de Cuidador.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _onSubmit,
                        icon: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        label: Text(
                          _isLoading ? 'Enviando...' : 'Enviar Link',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryFixed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'Proteção de dados em conformidade com a LGPD.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (_showSuccess) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  void _onSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Por favor, informe seu e-mail.');
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Informe um e-mail válido.');
      return;
    }

    if (_useFirebase) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (mounted) {
          setState(() {
            _showSuccess = true;
          });
        }
      } on FirebaseAuthException catch (e) {
        String msg = 'Erro ao enviar e-mail de redefinição.';
        if (e.code == 'user-not-found') {
          msg = 'Se o e-mail estiver cadastrado, você receberá as instruções.';
        } else if (e.code == 'invalid-email') {
          msg = 'E-mail informado é inválido.';
        }
        _showError(msg);
      } catch (e) {
        _showError('Erro de conexão: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      _showError(
        'Recuperação indisponível. Verifique a configuração do Firebase e tente novamente.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Recuperação de Senha',
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

  Widget _buildSuccessOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showSuccess = false),
      child: Container(
        color: AppColors.primary.withValues(alpha: 0.2),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.tertiaryContainer, width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixedDim,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppColors.onTertiaryFixedVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'E-mail Enviado!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Se o e-mail informado estiver em nosso sistema, você receberá um link de redefinição em alguns instantes. Não esqueça de verificar sua caixa de spam.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showSuccess = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Entendi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
}
