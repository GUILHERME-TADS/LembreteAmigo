import 'package:flutter/material.dart';

import '../services/app_permission_service.dart';
import '../theme/app_theme.dart';

class RequiredPermissionsScreen extends StatefulWidget {
  const RequiredPermissionsScreen({super.key});
  @override
  State<RequiredPermissionsScreen> createState() => _RequiredPermissionsScreenState();
}

class _RequiredPermissionsScreenState extends State<RequiredPermissionsScreen>
    with WidgetsBindingObserver {
  List<AppPermissionItem> _items = const [];
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final items = await AppPermissionService.instance.statuses();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _requestAll() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final items = await AppPermissionService.instance.requestAll();
    final complete = await AppPermissionService.instance.completeGateIfGranted();
    if (!mounted) return;
    setState(() { _items = items; _requesting = false; });
    if (complete) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _items.isNotEmpty && _items.every((item) => item.granted);
    final blocked = _items.any((item) => item.permanentlyDenied);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.security_rounded, size: 72, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('Permissões necessárias', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 10),
            const Text('Autorize todos os acessos para usar os lembretes e recursos de segurança.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, height: 1.35)),
            const SizedBox(height: 16),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = _items[index];
                    return Card(child: ListTile(
                      leading: Icon(item.granted ? Icons.check_circle : Icons.error_outline,
                        color: item.granted ? Colors.green : AppColors.error, size: 32),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(item.description),
                    ));
                  })),
            if (blocked) OutlinedButton.icon(
              onPressed: AppPermissionService.instance.openSettings,
              icon: const Icon(Icons.settings), label: const Text('Abrir configurações')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 64, child: ElevatedButton.icon(
              onPressed: _requesting ? null : _requestAll,
              icon: _requesting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : Icon(granted ? Icons.arrow_forward : Icons.verified_user),
              label: Text(granted ? 'Continuar' : 'Autorizar permissões',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            )),
          ]),
        )),
      ),
    );
  }
}
