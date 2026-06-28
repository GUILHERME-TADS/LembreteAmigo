import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SupervisorSettingsScreen extends StatefulWidget {
  const SupervisorSettingsScreen({super.key});

  @override
  State<SupervisorSettingsScreen> createState() => _SupervisorSettingsScreenState();
}

class _SupervisorSettingsScreenState extends State<SupervisorSettingsScreen> {
  bool _mockLowVolume = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mockLowVolume = prefs.getBool('mock_low_volume') ?? false;
    });
  }

  Future<void> _toggleMockLowVolume(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mock_low_volume', value);
    setState(() {
      _mockLowVolume = value;
    });
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
                  const Text('Configurações', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 40, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                    const Text('Maria Oliveira', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const Text('maria@exemplo.com', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _settingsGroup('Preferências', [
                _settingsTile(Icons.notifications, 'Notificações', 'Push, E-mail e SMS'),
                _settingsTile(Icons.volume_up, 'Som', 'Toque e vibração'),
                _settingsTile(Icons.dark_mode, 'Modo Escuro', 'Desativado'),
                _settingsSwitchTile(
                  Icons.volume_off,
                  'Simular Volume Baixo',
                  'Força alerta de som baixo nas telas do idoso',
                  _mockLowVolume,
                  _toggleMockLowVolume,
                ),
              ]),
              const SizedBox(height: 24),
              _settingsGroup('Monitoramento', [
                _settingsTile(Icons.timer, 'Intervalo de Verificação', 'A cada 30 min'),
                _settingsTile(Icons.sensors, 'Sensores Ativos', 'Movimento, Batimento'),
                _settingsTile(Icons.emergency, 'Contato de Emergência', '(11) 99999-9999'),
              ]),
              const SizedBox(height: 24),
              _settingsGroup('Conta', [
                _settingsTile(Icons.person, 'Editar Perfil', ''),
                _settingsTile(Icons.lock, 'Alterar Senha', ''),
                _settingsTile(Icons.logout, 'Sair da Conta', ''),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _settingsSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.secondaryContainer,
            activeTrackColor: AppColors.onSecondaryContainer.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}
