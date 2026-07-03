import 'dart:convert';
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
        'Por favor, digite o código de seis números fornecido pelo seu supervisor.',
        caller: this,
      );
    }
  }

  final List<String> _codeDigits = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _onNumberTap(String number) {
    if (_codeDigits.length >= 6) return;
    setState(() {
      _codeDigits.add(number);
      _errorMessage = null;
    });
    
    // Vocalize the number tapped
    TTSService.instance.falar(number, caller: this);

    if (_codeDigits.length == 6) {
      _verifyCode();
    }
  }

  void _onDeleteTap() {
    if (_codeDigits.isEmpty) return;
    setState(() {
      _codeDigits.removeLast();
      _errorMessage = null;
    });
    TTSService.instance.falar('Apagar', caller: this);
  }

  void _onClearTap() {
    if (_codeDigits.isEmpty) return;
    setState(() {
      _codeDigits.clear();
      _errorMessage = null;
    });
    TTSService.instance.falar('Limpar', caller: this);
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

  Future<void> _verifyCode() async {
    final enteredCode = _codeDigits.join();
    setState(() => _isLoading = true);

    try {
      if (_useFirebase) {
        // Query Firestore for matching pairingCode
        final query = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .where('pairingCode', isEqualTo: enteredCode)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          _handleFailure('Código inválido ou expirado. Verifique com seu supervisor.');
          return;
        }

        final doc = query.docs.first;
        final data = doc.data();

        // Check expiration
        final expiresStr = data['pairingCodeExpires'] as String?;
        if (expiresStr != null) {
          final expires = DateTime.parse(expiresStr);
          if (DateTime.now().isAfter(expires)) {
            _handleFailure('Este código já expirou. Peça ao seu supervisor para gerar outro.');
            return;
          }
        }

        // Successfully found and valid. Update status to active/linked
        await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(doc.id)
            .update({
          'status': 'active',
        });

        // Save local configuration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_idoso_id', doc.id);
        await prefs.setString('idoso_perfil', jsonEncode(data));

        _handleSuccess();
      } else {
        // Mode Simulation local
        if (enteredCode == '123456') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('paired_idoso_id', 'joao');
          
          final existingPerfilStr = prefs.getString('idoso_perfil');
          if (existingPerfilStr != null) {
            try {
              final Map<String, dynamic> data = jsonDecode(existingPerfilStr);
              data['status'] = 'active';
              await prefs.setString('idoso_perfil', jsonEncode(data));
            } catch (_) {}
            final localPerfil = {
              'nome': 'Idoso de Teste',
              'dataNascimento': '01/01/1950',
              'telefone': 'Não informado',
              'endereco': 'Não informado',
              'condicoes': <String>[],
              'status': 'active',
            };
            await prefs.setString('idoso_perfil', jsonEncode(localPerfil));
          }
          
          _handleSuccess();
        } else {
          _handleFailure('Código de simulação incorreto. Use o código 1 2 3 4 5 6.');
        }
      }
    } catch (e) {
      _handleFailure('Erro de conexão ao verificar o código. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _codeDigits.clear();
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
                      const SizedBox(height: 12),
                      const Text(
                        'Digite o código de 6 números que aparece no celular do seu ajudante ou cuidador.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Display of typed code
                      _buildCodeDisplay(),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
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
                      
                      const SizedBox(height: 24),
                      
                      // Keypad
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else ...[
                        _buildKeypad(),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildCodeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        String digit = '';
        if (index < _codeDigits.length) {
          digit = _codeDigits[index];
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 48,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: index == _codeDigits.length
                  ? AppColors.secondaryContainer
                  : AppColors.outlineVariant,
              width: index == _codeDigits.length ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionKeypadButton('Limpar', _onClearTap),
            _buildKeypadButton('0'),
            _buildActionKeypadButton('Apagar', _onDeleteTap),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number) {
    return SizedBox(
      width: 90,
      height: 72,
      child: ElevatedButton(
        onPressed: () => _onNumberTap(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.outlineVariant, width: 2),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeypadButton(String label, VoidCallback onTap) {
    final isDelete = label == 'Apagar';
    return SizedBox(
      width: 90,
      height: 72,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDelete ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
          foregroundColor: isDelete ? AppColors.onErrorContainer : AppColors.onSurfaceVariant,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDelete ? AppColors.error : AppColors.outlineVariant,
              width: 1,
            ),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label == 'Apagar' ? 'APAGAR' : 'LIMPAR',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDelete ? AppColors.error : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
