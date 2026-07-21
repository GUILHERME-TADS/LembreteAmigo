import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/lembrete_service.dart';
import '../services/message_service.dart';
import '../services/google_auth_service.dart';
import 'message_unread_badge.dart';

class SupervisorDrawer extends StatefulWidget {
  final String currentRoute;
  const SupervisorDrawer({super.key, required this.currentRoute});

  @override
  State<SupervisorDrawer> createState() => _SupervisorDrawerState();
}

class _SupervisorDrawerState extends State<SupervisorDrawer> {
  String _supervisorName = 'Cuidador';
  String _supervisorEmail = 'supervisor@lembreteamigo.com';
  String? _supervisorFoto;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSupervisorProfile();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final conn = await SessionRoleService.isSupervisorConnected();
    if (mounted) {
      setState(() {
        _isConnected = conn;
      });
    }
  }

  Future<void> _loadSupervisorProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _supervisorEmail = user.email ?? '';
          _supervisorName = user.displayName ?? 'Cuidador';
        });
      }
      try {
        if (Firebase.apps.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(user.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (mounted) {
              setState(() {
                _supervisorName = data['nome'] ?? _supervisorName;
                _supervisorFoto = data['fotoPath'] as String?;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar dados do supervisor no drawer: $e');
      }
    }
  }

  void _navigateTo(BuildContext context, String routeName) {
    final protectedRoutes = [
      '/messages',
      '/video-call-history',
      '/monthly-reports',
      '/effectiveness-feedback',
      '/activity-history',
      '/supervisor-edit-elderly-profile',
    ];

    if (protectedRoutes.contains(routeName) && !_isConnected) {
      Navigator.pop(context); // Close drawer to display snackbar clearly
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecte um dispositivo de idoso para acessar esta tela.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close drawer
    if (widget.currentRoute == routeName) return;

    if (routeName == '/supervisor-dashboard') {
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    } else {
      if (widget.currentRoute != '/supervisor-dashboard') {
        Navigator.pushReplacementNamed(context, routeName);
      } else {
        Navigator.pushNamed(context, routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(
              _supervisorName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _supervisorEmail,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                image: _supervisorFoto != null && _supervisorFoto!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_supervisorFoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _supervisorFoto == null || _supervisorFoto!.isEmpty
                  ? const Icon(Icons.person, color: AppColors.primary, size: 40)
                  : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home, color: AppColors.primary),
                  title: const Text(
                    'Painel Inicial',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _navigateTo(context, '/supervisor-dashboard'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_add,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Cadastrar/Emparelhar Idoso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _navigateTo(context, '/register-elderly'),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: const Text(
                      'Editar Dados do Idoso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(
                      context,
                      '/supervisor-edit-elderly-profile',
                    ),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.edit_calendar,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Editar Lembretes do Idoso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(context, '/activity-history'),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const MessageUnreadBadge(
                      child: Icon(Icons.forum, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Recados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(context, '/messages'),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.videocam,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Chamadas de Vídeo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(context, '/video-call-history'),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.analytics,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Relatórios Mensais',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(context, '/monthly-reports'),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Efetividade do Tratamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () =>
                        _navigateTo(context, '/effectiveness-feedback'),
                  ),
                ),
                Opacity(
                  opacity: _isConnected ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Histórico Detalhado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _navigateTo(context, '/activity-history'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: AppColors.primary),
                  title: const Text(
                    'Configurações',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _navigateTo(context, '/supervisor-settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.help, color: AppColors.primary),
                  title: const Text(
                    'Ajuda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _navigateTo(context, '/supervisor-help'),
                ),
              ],
            ),
          ),
          const Divider(),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sair da Conta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                
                showDialog(
                  context: context,
                  barrierColor: Colors.black87,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );

                try {
                  if (Firebase.apps.isNotEmpty) {
                    await GoogleAuthService.instance.signOut();
                  }
                } catch (_) {}
                await SessionRoleService.logout();
                await LembreteService.instance.reset();
                await MessageService.instance.reset();
                
                if (navigator.mounted) {
                  navigator.pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
