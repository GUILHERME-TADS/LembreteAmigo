import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ConnectedSettingsScreen extends StatefulWidget {
  const ConnectedSettingsScreen({super.key});

  @override
  State<ConnectedSettingsScreen> createState() => _ConnectedSettingsScreenState();
}

class _ConnectedSettingsScreenState extends State<ConnectedSettingsScreen> {
  bool _syncAuto = true;
  bool _pushNotifications = true;
  bool _audioWifi = true;
  bool _dataSaver = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncAuto = prefs.getBool('connected_settings_sync_auto') ?? true;
      _pushNotifications = prefs.getBool('connected_settings_push_notifications') ?? true;
      _audioWifi = prefs.getBool('connected_settings_audio_wifi') ?? true;
      _dataSaver = prefs.getBool('connected_settings_data_saver') ?? false;
      _loading = false;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'connected_settings_sync_auto') _syncAuto = value;
      if (key == 'connected_settings_push_notifications') _pushNotifications = value;
      if (key == 'connected_settings_audio_wifi') _audioWifi = value;
      if (key == 'connected_settings_data_saver') _dataSaver = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                      'Configurações',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixedDim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi, size: 16, color: AppColors.onTertiaryFixedVariant),
                        SizedBox(width: 4),
                        Text('Online', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onTertiaryFixedVariant)),
                      ],
                    ),
                  ),
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
                      child: const Icon(Icons.cloud_done, size: 40, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                    const Text('Sincronizado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const Text('Última sincronização: há 2 minutos', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _switchTile(
                Icons.sync,
                'Sincronização Automática',
                _syncAuto,
                (val) => _updatePreference('connected_settings_sync_auto', val),
              ),
              _switchTile(
                Icons.notifications,
                'Notificações Push',
                _pushNotifications,
                (val) => _updatePreference('connected_settings_push_notifications', val),
              ),
              _switchTile(
                Icons.cloud_upload,
                'Upload de Áudio via Wi-Fi',
                _audioWifi,
                (val) => _updatePreference('connected_settings_audio_wifi', val),
              ),
              _switchTile(
                Icons.storage,
                'Modo de Economia de Dados',
                _dataSaver,
                (val) => _updatePreference('connected_settings_data_saver', val),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.secondaryContainer,
          ),
        ],
      ),
    );
  }
}
