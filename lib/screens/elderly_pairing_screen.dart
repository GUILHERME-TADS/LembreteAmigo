import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/push_notification_service.dart';
import '../services/offline_sync_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/tts_service.dart';
import '../services/secure_cache_service.dart';
import '../widgets/index.dart';
import '../utils/firebase_helper.dart';

class ElderlyPairingScreen extends StatefulWidget {
  const ElderlyPairingScreen({super.key});

  @override
  State<ElderlyPairingScreen> createState() => _ElderlyPairingScreenState();
}

class _ElderlyPairingScreenState extends State<ElderlyPairingScreen> {
  bool _showModeSelection = true;
  String? _pairingCode;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakWelcome();
    });
  }

  void _speakWelcome() {
    if (_showModeSelection) {
      TTSService.instance.falar(
        'Como você quer usar o aplicativo? Você pode usar sozinho ou conectar com o celular do seu cuidador.',
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        'Aguarde enquanto o aplicativo gera o código de conexão para você mostrar ao seu cuidador.',
        caller: this,
      );
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _entrarSemSupervisor() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = await SessionRoleService.ensureStableElderlyId();
      await prefs.setBool('elderly_autonomous_mode', true);
      await PushNotificationService.instance.saveCurrentToken();

      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      final Map<String, dynamic> localPerfil = jsonStr != null
          ? jsonDecode(jsonStr) as Map<String, dynamic>
          : <String, dynamic>{};

      localPerfil.putIfAbsent('nome', () => 'Minha Conta');
      localPerfil.putIfAbsent('dataNascimento', () => '01/01/1950');
      localPerfil.putIfAbsent('telefone', () => '');
      localPerfil.putIfAbsent('endereco', () => '');
      localPerfil.putIfAbsent('fotoPath', () => null);
      final remotePerfil =
          ElderlyProfileRepository.instance.sanitize(localPerfil)
            ..remove('supervisorId')
            ..remove('status')
            ..remove('pairingCode')
            ..remove('pairingCodeExpires');
      remotePerfil['updatedAt'] = DateTime.now().toIso8601String();

      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(idosoId)
          .set(remotePerfil, SetOptions(merge: true));
      await FirebaseFunctions.instance.httpsCallable('unlinkElderly').call({
        'elderlyId': idosoId,
      });

      localPerfil.addAll(remotePerfil);
      localPerfil['supervisorId'] = null;
      localPerfil['status'] = 'pending';
      localPerfil.remove('pairingCode');
      localPerfil.remove('pairingCodeExpires');
      await SecureCacheService.instance.writeElderlyProfile(
        jsonEncode(localPerfil),
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/elderly-home',
          (route) => false,
          arguments: {
            'connected': false,
            'speak': 'Bem-vindo! Você já pode usar o aplicativo sozinho.',
          },
        );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar modo autônomo: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generatePairingCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_useFirebase) {
      setState(() {
        _errorMessage =
            'Não consegui conectar. Veja se a internet está ligada e tente de novo.';
        _isLoading = false;
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Entre com Google para gerar o código de conexão.');
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = await SecureCacheService.instance.readElderlyProfile();
      final Map<String, dynamic> localProfile = jsonStr != null
          ? jsonDecode(jsonStr) as Map<String, dynamic>
          : <String, dynamic>{};
      final safeProfile =
          ElderlyProfileRepository.instance.sanitize(localProfile)
            ..remove('supervisorId')
            ..remove('status')
            ..remove('pairingCode')
            ..remove('pairingCodeExpires');
      safeProfile.putIfAbsent('nome', () => 'Minha Conta');
      safeProfile['updatedAt'] = DateTime.now().toIso8601String();

      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(user.uid)
          .set(safeProfile, SetOptions(merge: true));

      final result = await FirebaseFunctions.instance
          .httpsCallable('createPairingCode')
          .call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final code = data['code'] as String? ?? '';
      if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
        throw StateError('O servidor retornou um código inválido.');
      }

      localProfile.addAll(safeProfile);
      localProfile['status'] = 'pending';
      localProfile['supervisorId'] = null;
      localProfile.remove('pairingCode');
      localProfile.remove('pairingCodeExpires');

      await prefs.setString('paired_idoso_id', user.uid);
      await prefs.setBool('elderly_autonomous_mode', true);
      await SecureCacheService.instance.writeElderlyProfile(
        jsonEncode(localProfile),
      );
      await PushNotificationService.instance.saveCurrentToken();

      if (!mounted) return;
      setState(() {
        _pairingCode = code;
        _isLoading = false;
      });

      _profileSubscription?.cancel();
      _profileSubscription = FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(user.uid)
          .snapshots()
          .listen(
            (snapshot) async {
              if (!snapshot.exists || snapshot.data() == null) return;
              final profile = snapshot.data()!;
              if (profile['status'] != 'active' ||
                  profile['supervisorId'] == null) {
                return;
              }

              await _profileSubscription?.cancel();
              final localPrefs = await SharedPreferences.getInstance();
              final cachedJson = await SecureCacheService.instance
                  .readElderlyProfile();
              final Map<String, dynamic> merged = cachedJson != null
                  ? jsonDecode(cachedJson) as Map<String, dynamic>
                  : <String, dynamic>{};
              merged.addAll(profile);
              merged.remove('pairingCode');
              merged.remove('pairingCodeExpires');

              await SecureCacheService.instance.writeElderlyProfile(
                jsonEncode(merged),
              );
              await localPrefs.setString('paired_idoso_id', user.uid);
              await localPrefs.setBool('elderly_autonomous_mode', false);

              final photoPath = profile['fotoPath'] as String?;
              if (photoPath != null && photoPath.isNotEmpty) {
                await localPrefs.setString('idoso_foto_path', photoPath);
              }

              await SessionRoleService.syncVoiceAndListeningSettings(profile);
              _handleSuccess();
            },
            onError: (Object error) {
              debugPrint('Erro ao escutar atualizações de pareamento: $error');
            },
          );

      TTSService.instance.falar(
        'Seu código para conectar é: ${code.split('').join(' ')}. '
        'Mostre este número para o seu cuidador.',
        caller: this,
      );
    } catch (error) {
      debugPrint('Erro ao gerar código de pareamento: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Não consegui criar o código. Veja se a internet está ligada e tente de novo.';
        _isLoading = false;
      });
    }
  }

  void _handleSuccess() async {
    TTSService.instance.parar(caller: this);
    await PushNotificationService.instance.saveCurrentToken();
    await OfflineSyncService.instance.syncPendingWrites();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/elderly-home',
      (route) => false,
      arguments: {
        'connected': true,
        'speak': 'Pronto. O celular do seu cuidador foi conectado. Bem-vindo.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta é a tela para conectar com quem cuida de você. Você pode usar o aplicativo sozinho ou conectar com o celular do seu cuidador para ele acompanhar você.',
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (!_showModeSelection) {
                                setState(() {
                                  _showModeSelection = true;
                                });
                                _speakWelcome();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Lembrete Amigo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_showModeSelection) ...[
                        const SizedBox(height: 32),
                        const Text(
                          'Como você vai usar?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Escolha uma das opções abaixo para começar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SeniorButton(
                          label: 'Usar sozinho',
                          icon: Icons.person_outline,
                          backgroundColor: AppColors.secondaryContainer,
                          textColor: AppColors.onSecondaryContainer,
                          onPressed: _entrarSemSupervisor,
                        ),
                        const SizedBox(height: 24),
                        SeniorButton(
                          label: 'Usar com cuidador',
                          icon: Icons.supervisor_account,
                          backgroundColor: AppColors.primary,
                          textColor: Colors.white,
                          onPressed: () {
                            setState(() {
                              _showModeSelection = false;
                              _errorMessage = null;
                            });
                            _speakWelcome();
                            _generatePairingCode();
                          },
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Conectar com Cuidador',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            TTSService.instance.parar(caller: this);
                            TTSService.instance.falar(
                              'Mostre este número para quem cuida de você. Ela vai digitar esse número no celular dela para conectar os dois aparelhos.',
                              caller: this,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volume_up_rounded,
                                  color: AppColors.onSecondaryContainer,
                                  size: 28,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'OUVIR COMO CONECTAR',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        else if (_pairingCode != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: Container(
                                  width: 48,
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _pairingCode![index],
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                        if (!_isLoading) ...[
                          const Center(
                            child: Text(
                              'Aguardando o cuidador digitar o código...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: OutlinedButton.icon(
                            onPressed: _generatePairingCode,
                            icon: const Icon(Icons.refresh, size: 28),
                            label: const Text(
                              'Gerar novo código',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
