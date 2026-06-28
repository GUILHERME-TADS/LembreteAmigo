import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/senior_button.dart';

class SupervisorLoginScreen extends StatefulWidget {
  const SupervisorLoginScreen({super.key});

  @override
  State<SupervisorLoginScreen> createState() => _SupervisorLoginScreenState();
}

class _SupervisorLoginScreenState extends State<SupervisorLoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    _passwordController.dispose();
    super.dispose();
  }

  void _entrar() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_useFirebase) {
      if (email.isEmpty || password.isEmpty) {
        _showError('Por favor, preencha todos os campos.');
        return;
      }

      setState(() => _isLoading = true);

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
      } on FirebaseAuthException catch (e) {
        String msg = 'Erro ao entrar.';
        if (e.code == 'user-not-found') {
          msg = 'E-mail não cadastrado.';
        } else if (e.code == 'wrong-password') {
          msg = 'Senha incorreta.';
        } else if (e.code == 'invalid-email') {
          msg = 'E-mail inválido.';
        } else if (e.code == 'user-disabled') {
          msg = 'Esta conta foi desativada.';
        }
        _showError(msg);
      } catch (e) {
        _showError('Erro de conexão: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Bypass local
      Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erro de Acesso', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.health_and_safety, size: 40, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Cuidador',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 48),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bem-vindo, Supervisor',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: AppColors.onSurface),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Acesse o painel administrativo do Lembrete Amigo.',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SeniorInputField(
                        label: 'E-mail Corporativo',
                        placeholder: 'nome@exemplo.com',
                        prefixIcon: Icons.mail,
                        controller: _emailController,
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SENHA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                child: const Text(
                                  'Esqueci minha senha',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.05,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              border: Border.all(color: AppColors.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Icon(Icons.lock, color: AppColors.outline),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(fontSize: 18),
                                    decoration: const InputDecoration(
                                      hintText: '••••••••',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: AppColors.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: false,
                              onChanged: (_) {},
                              fillColor: WidgetStateProperty.all(AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Lembrar neste dispositivo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _entrar,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            _isLoading ? 'Carregando...' : 'Entrar',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryContainer,
                            foregroundColor: AppColors.onSecondaryFixed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Não possui acesso?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/supervisor-register'),
                            child: const Text(
                              'Criar conta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: AppColors.outlineVariant),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 32,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Termos de Uso', style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Privacidade', style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Suporte Técnico', style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
