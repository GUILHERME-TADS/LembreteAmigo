import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

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

  bool get _useFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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
        'Como você deseja usar o aplicativo? Você pode entrar de forma autônoma para usar sozinho, ou com um supervisor.',
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        'Aguarde enquanto o aplicativo gera o código de conexão para você mostrar ao seu ajudante.',
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
      await prefs.setString('paired_idoso_id', 'idoso_autonomo');
      
      final Map<String, dynamic> localPerfil = {
        'nome': 'Minha Conta',
        'dataNascimento': '01/01/1950',
        'telefone': '',
        'endereco': '',
        'condicoes': <dynamic>[],
        'fotoPath': null
      };
      await prefs.setString('idoso_perfil', jsonEncode(localPerfil));
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/elderly-home',
          (route) => false,
          arguments: {
            'connected': false,
            'speak': 'Bem-vindo! Modo autônomo ativado.',
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
        _errorMessage = 'O Firebase não está ativo. Conecte-se à internet para realizar o vínculo.';
        _isLoading = false;
      });
      return;
    }

    final random = math.Random();
    final code = (100000 + random.nextInt(900000)).toString();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final Map<String, dynamic> localPerfil = {
        'nome': 'Minha Conta',
        'dataNascimento': '',
        'telefone': '',
        'endereco': '',
        'condicoes': <String>[],
        'status': 'pending',
        'pairingCode': code,
        'pairingCodeExpires': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        'fotoPath': null,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .add(localPerfil);
      
      await prefs.setString('paired_idoso_id', docRef.id);
      await prefs.setString('idoso_perfil', jsonEncode(localPerfil));

      setState(() {
        _pairingCode = code;
        _isLoading = false;
      });

      // Iniciar escuta das atualizações do documento no Firestore
      _profileSubscription?.cancel();
      _profileSubscription = FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(docRef.id)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          if (data['status'] == 'active') {
            // Conectado com sucesso pelo supervisor!
            _profileSubscription?.cancel();
            final prefsInstance = await SharedPreferences.getInstance();
            await prefsInstance.setString('idoso_perfil', jsonEncode(data));
            
            // Se tiver fotoPath no Firestore, salva também em idoso_foto_path
            final fotoPath = data['fotoPath'] as String?;
            if (fotoPath != null && fotoPath.isNotEmpty) {
              await prefsInstance.setString('idoso_foto_path', fotoPath);
            }
            
            _handleSuccess();
          }
        }
      });
      
      TTSService.instance.falar(
        'Seu código de conexão é: ${code.split('').join(' ')}. Mostre este código para o seu ajudante.',
        caller: this,
      );

    } catch (e) {
      debugPrint('Erro ao gerar código de pareamento: $e');
      setState(() {
        _errorMessage = 'Erro ao gerar o código. Verifique sua conexão e tente novamente.';
        _isLoading = false;
      });
    }
  }

  void _handleSuccess() async {
    TTSService.instance.parar(caller: this);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/elderly-home',
      (route) => false,
      arguments: {
        'connected': true,
        'speak': 'Aparelho conectado com sucesso! Bem vindo.',
      },
    );
  }

  void _handleFailure(String message) {
    setState(() {
      _errorMessage = message;
    });
    TTSService.instance.falar(message, caller: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 36),
                          onPressed: () {
                            if (!_showModeSelection) {
                              setState(() {
                                _showModeSelection = true;
                              });
                              _speakWelcome();
                            } else {
                              Navigator.pop(context);
                            }
                          },
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
                    const MeExplicaButton(
                      textoExplicacao: 'Olá! Esta é a tela para conectar o aplicativo com quem cuida de você. Aqui você pode escolher se vai usar o aplicativo sozinho ou se vai conectar com o celular do seu ajudante ou cuidador para ele te acompanhar.',
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
                        label: 'USAR SOZINHO',
                        icon: Icons.person_outline,
                        backgroundColor: AppColors.secondaryContainer,
                        textColor: AppColors.onSecondaryContainer,
                        onPressed: _entrarSemSupervisor,
                      ),
                      const SizedBox(height: 24),
                      SeniorButton(
                        label: 'CONECTAR COM AJUDANTE',
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
                        'Conectar com Ajudante',
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
                        'Mostre ou diga este código para o seu ajudante para ele poder te cadastrar no celular dele:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Código de Pareamento Gerado
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else if (_pairingCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _pairingCode!.split('').join('  '),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        
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
                            'Aguardando o ajudante digitar o código...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
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
                            'GERAR NOVO CÓDIGO',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 2),
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
