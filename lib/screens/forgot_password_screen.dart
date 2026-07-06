import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _showSuccess = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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
                  children: [
                    const SizedBox(height: 80),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        color: AppColors.onSecondaryContainer,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recuperar Senha',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Insira seu e-mail de supervisor cadastrado para enviarmos as instruções de redefinição.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildEmailField(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _onSubmit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        label: Text(
                          _isLoading ? 'Enviando...' : 'Enviar Link',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                      label: const Text(
                        'Voltar ao Login',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Proteção de dados em conformidade com a LGPD.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
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

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-mail',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(Icons.mail, color: AppColors.outline),
              ),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'nome@exemplo.com',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Verifique se o e-mail inserido é o mesmo utilizado no seu ID de Supervisor.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
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
        title: const Text('Recuperação de Senha', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  child: const Icon(Icons.check_circle, size: 48, color: AppColors.onTertiaryFixedVariant),
                ),
                const SizedBox(height: 16),
                const Text(
                  'E-mail Enviado!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
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
                    child: const Text('Entendi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
