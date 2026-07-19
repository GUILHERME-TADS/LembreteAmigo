import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/push_notification_service.dart';
import '../services/google_auth_service.dart';
import '../widgets/index.dart';
import '../utils/firebase_helper.dart';

class SupervisorLoginScreen extends StatefulWidget {
  const SupervisorLoginScreen({super.key});

  @override
  State<SupervisorLoginScreen> createState() => _SupervisorLoginScreenState();
}

class _SupervisorLoginScreenState extends State<SupervisorLoginScreen> {
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _entrar() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_useFirebase) {
      if (email.isEmpty || password.isEmpty) {
        _showError('Por favor, preencha todos os campos.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_useFirebase) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(user.uid)
              .set({
                'nome': user.displayName ?? 'Cuidador',
                'email': user.email ?? email,
                'updatedAt': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
        }
        await SessionRoleService.setSupervisor();
        await SessionRoleService.restoreSupervisorIdosoLink();
        await PushNotificationService.instance.saveCurrentToken();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
      } else {
        await SessionRoleService.setSupervisor();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
      }
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
  }

  Future<void> _entrarComGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final credential = await GoogleAuthService.instance.signIn();
      final user = credential.user;
      if (user == null) {
        throw StateError('O Google nao retornou uma conta valida.');
      }
      await FirebaseFirestore.instance
          .collection('supervisores')
          .doc(user.uid)
          .set({
            'nome': user.displayName ?? 'Cuidador',
            'email': user.email ?? '',
            'fotoUrl': user.photoURL,
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      await SessionRoleService.setSupervisor();
      await SessionRoleService.restoreSupervisorIdosoLink();
      await PushNotificationService.instance.saveCurrentToken();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/supervisor-dashboard',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(
        e.code == 'popup-closed-by-user' || e.code == 'canceled'
            ? 'Login Google cancelado.'
            : 'Nao foi possivel entrar com Google: ${e.message ?? e.code}',
      );
    } catch (e) {
      _showError('Nao foi possivel entrar com Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Erro de Acesso',
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const SupervisorHeader(),
                      const SizedBox(height: 48),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bem-vindo, Cuidador',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: AppColors.onSurface,
                              ),
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
                        label: 'E-mail',
                        placeholder: 'nome@exemplo.com',
                        prefixIcon: Icons.mail,
                        controller: _emailController,
                      ),
                      const SizedBox(height: 24),
                      SeniorInputField(
                        label: 'Senha',
                        placeholder: '••••••••',
                        prefixIcon: Icons.lock,
                        isPassword: true,
                        controller: _passwordController,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password'),
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
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _entrar,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            _isLoading ? 'Carregando...' : 'Entrar',
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
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _entrarComGoogle,
                          icon: const Icon(Icons.account_circle, size: 28),
                          label: const Text(
                            'Entrar com Google',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/supervisor-register',
                            ),
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
                            onPressed: () {
                              showInfoBottomSheet(
                                context: context,
                                title: 'Termos de Uso',
                                content:
                                    'Ao utilizar o Lembrete Amigo, você concorda com nossos termos de uso. O aplicativo foi feito para auxiliar a lembrança de rotinas, mas não substitui recomendações médicas ou supervisão profissional direta. Use de forma responsável e mantenha os dados atualizados.',
                                icon: Icons.description_outlined,
                              );
                            },
                            child: const Text(
                              'Termos de Uso',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              showInfoBottomSheet(
                                context: context,
                                title: 'Política de Privacidade',
                                content:
                                    'Sua privacidade é nossa prioridade. Todos os dados cadastrados, incluindo histórico de medicamentos e alertas de rotina, são criptografados e armazenados com segurança. Não compartilhamos informações pessoais com terceiros.',
                                icon: Icons.security_outlined,
                              );
                            },
                            child: const Text(
                              'Privacidade',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              showInfoBottomSheet(
                                context: context,
                                title: 'Suporte Técnico',
                                content:
                                    'Para problemas técnicos, falhas no carregamento de áudio ou sincronização de dados:\n\nEntre em contato via suporte@lembreteamigo.com informando o modelo do dispositivo e a descrição do erro.',
                                icon: Icons.build_outlined,
                              );
                            },
                            child: const Text(
                              'Suporte Técnico',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
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
