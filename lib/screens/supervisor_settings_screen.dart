import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_mode_selector.dart';
import '../services/care_preferences_service.dart';
import '../services/session_role_service.dart';
import '../services/lembrete_service.dart';
import '../services/message_service.dart';
import '../services/google_auth_service.dart';

class SupervisorSettingsScreen extends StatefulWidget {
  const SupervisorSettingsScreen({super.key});

  @override
  State<SupervisorSettingsScreen> createState() =>
      _SupervisorSettingsScreenState();
}

class _SupervisorSettingsScreenState extends State<SupervisorSettingsScreen> {
  String _userName = 'Carregando...';
  String _userEmail = '';
  String? _fotoPath;
  bool _dailySummaryEnabled = true;
  TimeOfDay _dailySummaryTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final carePreferences = await CarePreferencesService.instance.load();
    if (mounted) {
      setState(() {
        _dailySummaryEnabled = carePreferences.dailySummaryEnabled;
        _dailySummaryTime = TimeOfDay(
          hour: carePreferences.dailySummaryHour,
          minute: carePreferences.dailySummaryMinute,
        );
      });
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? '';
        _userName = user.displayName ?? 'Cuidador';
      });
      try {
        if (Firebase.apps.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(user.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            setState(() {
              _userName = data['nome'] ?? _userName;
              _fotoPath = data['fotoPath'] as String?;
            });
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar dados do supervisor no Firestore: $e');
      }
    }
  }

  Future<void> _setDailySummaryEnabled(bool enabled) async {
    setState(() => _dailySummaryEnabled = enabled);
    await CarePreferencesService.instance.setDailySummary(
      enabled: enabled,
      hour: _dailySummaryTime.hour,
      minute: _dailySummaryTime.minute,
    );
  }

  Future<void> _pickDailySummaryTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _dailySummaryTime,
      helpText: 'HORÁRIO DO RESUMO DIÁRIO',
    );
    if (selected == null || !mounted) return;
    setState(() => _dailySummaryTime = selected);
    await CarePreferencesService.instance.setDailySummary(
      enabled: _dailySummaryEnabled,
      hour: selected.hour,
      minute: selected.minute,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Resumo diário programado para ${selected.format(context)}.',
        ),
      ),
    );
  }

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Alterar Foto de Perfil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: const Text('Tirar Foto', style: TextStyle(fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera, user.uid);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text(
                  'Escolher da Galeria',
                  style: TextStyle(fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery, user.uid);
                },
              ),
              if (_fotoPath != null && _fotoPath!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete, color: AppColors.error),
                  title: Text(
                    'Remover Foto',
                    style: TextStyle(fontSize: 18, color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto(user.uid);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source, String uid) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(width: 16),
                Text('Enviando foto...'),
              ],
            ),
          ),
        );
      }

      final file = File(image.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('perfis_supervisor')
          .child(uid)
          .child('profile.jpg');

      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('supervisores')
            .doc(uid)
            .set({'fotoPath': downloadUrl}, SetOptions(merge: true));
      }

      setState(() {
        _fotoPath = downloadUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar foto do supervisor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar foto: $e')));
      }
    }
  }

  Future<void> _removePhoto(String uid) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('supervisores')
            .doc(uid)
            .set({'fotoPath': null}, SetOptions(merge: true));

        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('perfis_supervisor')
              .child(uid)
              .child('profile.jpg');
          await ref.delete();
        } catch (_) {}
      }

      setState(() {
        _fotoPath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil removida.')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover foto do supervisor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          GestureDetector(
                            onTap: _changePhoto,
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                    image:
                                        _fotoPath != null &&
                                            _fotoPath!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_fotoPath!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _fotoPath == null || _fotoPath!.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 40,
                                          color: AppColors.onPrimaryContainer,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            _userEmail,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const ThemeModeSelector(),
                    const SizedBox(height: 24),
                    _settingsGroup('Resumo e treinamento', [
                      SwitchListTile(
                        secondary: Icon(
                          Icons.summarize_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Lembrete do resumo diário',
                          style: TextStyle(fontSize: 18),
                        ),
                        subtitle: const Text(
                          'Receba um aviso para revisar pendências e confirmações.',
                        ),
                        value: _dailySummaryEnabled,
                        onChanged: _setDailySummaryEnabled,
                      ),
                      _settingsTile(
                        Icons.schedule,
                        'Horário do resumo',
                        _dailySummaryTime.format(context),
                        onTap: _dailySummaryEnabled
                            ? _pickDailySummaryTime
                            : null,
                      ),
                      _settingsTile(
                        Icons.school_outlined,
                        'Modo de treinamento',
                        'Pratique confirmações sem alterar dados reais',
                        onTap: () =>
                            Navigator.pushNamed(context, '/practice-mode'),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _settingsGroup('Ações e Preferências', [
                      _settingsTile(
                        Icons.lock_outline,
                        'Alterar Senha',
                        'Redefinir sua senha de acesso',
                        onTap: () =>
                            Navigator.pushNamed(context, '/forgot-password'),
                      ),
                      _settingsTile(
                        Icons.logout,
                        'Sair da Conta',
                        'Desconectar do aplicativo',
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          showDialog(
                            context: context,
                            barrierColor: Colors.black87,
                            barrierDismissible: false,
                            builder: (_) => Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
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
                            navigator.pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
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
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppColors.onSurfaceVariant,
            ),
          ),
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

  Widget _settingsTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
          ),
          Expanded(
            child: Text(
              'Configurações',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
