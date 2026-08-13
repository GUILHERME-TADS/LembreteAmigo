import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_theme.dart';
import '../utils/firebase_helper.dart';
import '../services/lembrete_service.dart';
import '../services/message_service.dart';
import '../services/session_role_service.dart';
import '../services/secure_cache_service.dart';

class RegisterElderlyScreen extends StatefulWidget {
  const RegisterElderlyScreen({super.key});

  @override
  State<RegisterElderlyScreen> createState() => _RegisterElderlyScreenState();
}

class _RegisterElderlyScreenState extends State<RegisterElderlyScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _pairedIdosoId;
  String? _pairedIdosoName;

  bool get _useFirebase => FirebaseHelper.isInitialized;

  String get _fullCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _loadPairedIdoso();

    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _controllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[i].text.length,
          );
        }
        if (mounted) setState(() {});
      });

      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[i].text.isEmpty && i > 0) {
            _controllers[i - 1].clear();
            _focusNodes[i - 1].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  Future<void> _loadPairedIdoso() async {
    final prefs = await SharedPreferences.getInstance();
    final docId = prefs.getString('selected_idoso_id');
    if (docId != null) {
      String? name;
      if (_useFirebase) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(docId)
              .get();
          if (doc.exists) {
            name = doc.data()?['nome'] as String?;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _pairedIdosoId = docId;
          _pairedIdosoName = name ?? 'Idoso Conectado';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _pairedIdosoId = null;
          _pairedIdosoName = null;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _desvincular() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Desconectar Aparelho?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        content: Text(
          'Deseja realmente desconectar o dispositivo de ${_pairedIdosoName ?? 'Idoso Conectado'} do seu painel?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'NÃO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'SIM, DESCONECTAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) return;

    if (_useFirebase) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Faça login novamente antes de desconectar um idoso.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await LembreteService.instance.reset();
      await MessageService.instance.reset();
      await SessionRoleService.stopWatchingElderlyConnection();

      if (_pairedIdosoId != null && _useFirebase) {
        await FirebaseFunctions.instance.httpsCallable('unlinkElderly').call({
          'elderlyId': _pairedIdosoId,
        });
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_idoso_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispositivo desconectado com sucesso.'),
          ),
        );
      }
      for (final c in _controllers) {
        c.clear();
      }
      await _loadPairedIdoso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao desconectar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cadastrar() async {
    final code = _fullCode.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, digite o código de 6 dígitos exibido no celular do idoso.',
          ),
        ),
      );
      return;
    }

    if (!_useFirebase) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_idoso_id', 'idoso_simulado');
      if (FirebaseHelper.isDemoRecording) {
        await SecureCacheService.instance.writeElderlyProfile(
          jsonEncode({
            'nome': 'Dona Maria',
            'endereco': 'Residência cadastrada',
            'status': 'active',
            'supervisorId': 'cuidador_demo',
          }),
        );
        await prefs.setBool('elderly_autonomous_mode', false);
      }
      await _loadPairedIdoso();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Vínculo Realizado (Simulado)!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: AppColors.success),
              SizedBox(height: 16),
              Text(
                'O dispositivo do idoso foi vinculado com sucesso ao seu painel (modo simulado).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text(
                'Concluir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faca login novamente antes de vincular um idoso.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('claimPairingCode')
          .call({'code': code});
      final response = Map<String, dynamic>.from(result.data as Map);
      final docId = response['elderlyId'] as String? ?? '';
      if (docId.isEmpty) {
        throw StateError('O servidor não confirmou o dispositivo conectado.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_idoso_id', docId);
      await _loadPairedIdoso();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Vínculo Realizado!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: AppColors.success),
              SizedBox(height: 16),
              Text(
                'O dispositivo do idoso foi vinculado com sucesso ao seu painel de controle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text(
                'Concluir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar cadastro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPinInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        final controller = _controllers[index];
        final focusNode = _focusNodes[index];
        final isFocused = focusNode.hasFocus;
        final hasDigit = controller.text.isNotEmpty;

        return Flexible(
          child: Container(
            height: 58,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(maxWidth: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? AppColors.primary
                    : (hasDigit
                          ? AppColors.secondary
                          : AppColors.outlineVariant),
                width: isFocused ? 2.5 : 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              showCursor: true,
              cursorColor: AppColors.primary,
              cursorWidth: 2.5,
              cursorHeight: 28,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: (val) {
                if (val.isNotEmpty) {
                  if (val.length > 1) {
                    final newChar = val.substring(val.length - 1);
                    controller.text = newChar;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: newChar.length),
                    );
                  }
                  if (index < 5) {
                    _focusNodes[index + 1].requestFocus();
                  }
                } else {
                  if (index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                }
                setState(() {});
              },
            ),
          ),
        );
      }),
    );
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
                    if (_pairedIdosoId != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryContainer,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.link,
                              size: 64,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Celular Conectado',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pairedIdosoName ?? 'Idoso Conectado',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _desvincular,
                                icon: const Icon(
                                  Icons.link_off,
                                  size: 24,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'DESCONECTAR APARELHO',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Text(
                        'Conectar Celular do Idoso',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Insira o código de conexão de 6 dígitos que está sendo exibido na tela do idoso para vincular o dispositivo ao seu painel.',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildPinInput(),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _cadastrar,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link, size: 28),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          label: Text(
                            _isLoading
                                ? 'CONECTANDO...'
                                : 'VINCULAR DISPOSITIVO',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
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
          ],
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
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          Expanded(
            child: Text(
              'Lembrete Amigo',
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
