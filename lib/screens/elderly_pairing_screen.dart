import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/session_role_service.dart';
import '../services/push_notification_service.dart';
import '../services/offline_sync_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/tts_service.dart';
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

      final jsonStr = prefs.getString('idoso_perfil');
      final Map<String, dynamic> localPerfil = jsonStr != null
          ? jsonDecode(jsonStr) as Map<String, dynamic>
          : <String, dynamic>{};

      localPerfil.putIfAbsent('nome', () => 'Minha Conta');
      localPerfil.putIfAbsent('dataNascimento', () => '01/01/1950');
      localPerfil.putIfAbsent('telefone', () => '');
      localPerfil.putIfAbsent('endereco', () => '');
      localPerfil.putIfAbsent('fotoPath', () => null);
      final remotePerfil =
          ElderlyProfileRepository.instance.sanitize(localPerfil);
      remotePerfil['supervisorId'] = null;
      remotePerfil['status'] = 'pending';
      remotePerfil['updatedAt'] = DateTime.now().toIso8601String();

      localPerfil.addAll(remotePerfil);

      await prefs.setString('idoso_perfil', jsonEncode(localPerfil));
      await OfflineSyncService.instance.setOrQueue(
        'idoso_perfil',
        idosoId,
        remotePerfil,
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
      final code = await _generateUniquePairingCode();
      final prefs = await SharedPreferences.getInstance();

      final jsonStr = prefs.getString('idoso_perfil');
      final Map<String, dynamic> localPerfil = jsonStr != null
          ? jsonDecode(jsonStr) as Map<String, dynamic>
          : <String, dynamic>{};

      final pairingProfile =
          ElderlyProfileRepository.instance.sanitize(localPerfil);
      pairingProfile.putIfAbsent('nome', () => 'Minha Conta');
      pairingProfile.putIfAbsent('dataNascimento', () => '');
      pairingProfile.putIfAbsent('telefone', () => '');
      pairingProfile.putIfAbsent('endereco', () => '');
      pairingProfile.putIfAbsent('fotoPath', () => null);
      pairingProfile['status'] = 'pending';
      pairingProfile['pairingCode'] = code;
      pairingProfile['pairingCodeExpires'] = DateTime.now()
          .add(const Duration(hours: 2))
          .toIso8601String();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Entre com Google para gerar o codigo de conexao.');
      }
      final uid = user.uid;

      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(uid)
          .set(pairingProfile);

      await prefs.setString('paired_idoso_id', uid);
      await prefs.setBool('elderly_autonomous_mode', true);
      await prefs.setString('idoso_perfil', jsonEncode(pairingProfile));
      await PushNotificationService.instance.saveCurrentToken();

      if (!mounted) return;
      setState(() {
        _pairingCode = code;
        _isLoading = false;
      });

      // Iniciar escuta das atualizações do documento no Firestore
      _profileSubscription?.cancel();
      _profileSubscription = FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(uid)
          .snapshots()
          .listen(
            (snapshot) async {
              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data()!;
                if (data['status'] == 'active') {
                  // Conectado com sucesso pelo supervisor!
                  _profileSubscription?.cancel();
                  final prefsInstance = await SharedPreferences.getInstance();

                  // Preserva dados locais existentes, só atualiza conexão do Firestore
                  final jsonStr = prefsInstance.getString('idoso_perfil');
                  final Map<String, dynamic> merged = jsonStr != null
                      ? jsonDecode(jsonStr) as Map<String, dynamic>
                      : <String, dynamic>{};

                  merged['status'] = data['status'];
                  if (data['supervisorId'] != null) {
                    merged['supervisorId'] = data['supervisorId'];
                  }

                  for (final key in [
                    'nome',
                    'dataNascimento',
                    'telefone',
                    'endereco',
                    'fotoPath',
                  ]) {
                    merged.putIfAbsent(key, () => data[key]);
                  }

                  await prefsInstance.setString(
                    'idoso_perfil',
                    jsonEncode(merged),
                  );
                  await prefsInstance.setString('paired_idoso_id', uid);
                  await prefsInstance.setBool('elderly_autonomous_mode', false);

                  final fotoPath = data['fotoPath'] as String?;
                  if (fotoPath != null && fotoPath.isNotEmpty) {
                    await prefsInstance.setString('idoso_foto_path', fotoPath);
                  }

                  await SessionRoleService.syncVoiceAndListeningSettings(data);

                  _handleSuccess();
                }
              }
            },
            onError: (Object error) {
              debugPrint('Erro ao escutar atualizações de pareamento: $error');
            },
          );

      TTSService.instance.falar(
        'Seu código para conectar é: ${code.split('').join(' ')}. Mostre este número para o seu cuidador. O seu cuidador vai digitar esse número no celular dele para conectar os dois aparelhos.',
        caller: this,
      );
    } catch (e) {
      debugPrint('Erro ao gerar código de pareamento: $e');
      setState(() {
        _errorMessage =
            'Não consegui criar o código. Veja se a internet está ligada e tente de novo.';
        _isLoading = false;
      });
    }
  }

  Future<String> _generateUniquePairingCode() async {
    final random = math.Random.secure();
    return (100000 + random.nextInt(900000)).toString();
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
                        const SizedBox(height: 16),
                        const Text(
                          'Mostre este número para quem cuida de você. Ela vai digitar esse número no celular dela para conectar os dois aparelhos:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
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
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  border: Border.all(
                                    color: Color(0xFF1976D2),
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _pairingCode!.substring(0, 3),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0D47A1),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  border: Border.all(
                                    color: Color(0xFFF57C00),
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _pairingCode!.substring(3, 6),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFE65100),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
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
