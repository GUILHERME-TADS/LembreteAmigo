import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class RegisterElderlyScreen extends StatefulWidget {
  const RegisterElderlyScreen({super.key});

  @override
  State<RegisterElderlyScreen> createState() => _RegisterElderlyScreenState();
}

class _RegisterElderlyScreenState extends State<RegisterElderlyScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isLoading = false;
  String? _pairedIdosoId;
  String? _pairedIdosoName;

  // Blinking cursor state
  Timer? _cursorTimer;
  bool _cursorVisible = true;

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
    _loadPairedIdoso();
    _pinFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_pinFocusNode.hasFocus) {
      _startCursorTimer();
    } else {
      _stopCursorTimer();
    }
  }

  void _startCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    });
  }

  void _stopCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    if (mounted) {
      setState(() {
        _cursorVisible = false;
      });
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
    _codeController.dispose();
    _pinFocusNode.removeListener(_onFocusChange);
    _pinFocusNode.dispose();
    _cursorTimer?.cancel();
    super.dispose();
  }

  Future<void> _desvincular() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desconectar Aparelho?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text(
          'Deseja realmente desconectar o dispositivo de ${_pairedIdosoName ?? 'Idoso Conectado'} do seu painel?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NÃO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIM, DESCONECTAR', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      if (_pairedIdosoId != null) {
        if (_useFirebase) {
          await FirebaseFirestore.instance
              .collection('idoso_perfil')
              .doc(_pairedIdosoId)
              .update({
                'supervisorId': null,
                'status': 'pending',
              });
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_idoso_id');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo desconectado com sucesso.')),
        );
      }
      _codeController.clear();
      await _loadPairedIdoso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desconectar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cadastrar() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o código de 6 dígitos exibido no celular do idoso.')),
      );
      return;
    }

    if (!_useFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O Firebase não está ativo. Conecte-se à internet para realizar o vínculo.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .where('pairingCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido ou já utilizado. Verifique no celular do idoso.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final doc = query.docs.first;
      final docId = doc.id;

      final data = doc.data();
      final expiresStr = data['pairingCodeExpires'] as String?;
      if (expiresStr != null) {
        final expires = DateTime.parse(expiresStr);
        if (DateTime.now().isAfter(expires)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este código expirou. Gere um novo código no celular do idoso.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final updateData = {
        'supervisorId': FirebaseAuth.instance.currentUser?.uid,
        'status': 'active',
      };

      await FirebaseFirestore.instance
          .collection('idoso_perfil')
          .doc(docId)
          .update(updateData);

      await FirebaseFirestore.instance
          .collection('idosos')
          .doc(docId)
          .set(updateData, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_idoso_id', docId);

      await _loadPairedIdoso();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Vínculo Realizado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
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
              child: const Text('Concluir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar cadastro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPinInput() {
    return Stack(
      children: [
        // Hidden TextField that captures input
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            height: 60,
            child: TextField(
              controller: _codeController,
              focusNode: _pinFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),
        ),
        // Row of 6 styled squares
        GestureDetector(
          onTap: () {
            _pinFocusNode.requestFocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: 60,
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                final text = _codeController.text;
                final hasDigit = index < text.length;
                final digit = hasDigit ? text[index] : '';
                final isFocused = _pinFocusNode.hasFocus && index == text.length;

                Widget childWidget;
                if (hasDigit) {
                  childWidget = Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  );
                } else if (isFocused && _cursorVisible) {
                  childWidget = Container(
                    width: 2.5,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                } else {
                  childWidget = const SizedBox.shrink();
                }

                return Container(
                  width: 48,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFocused
                          ? AppColors.primary
                          : (hasDigit ? AppColors.secondary : AppColors.outlineVariant),
                      width: isFocused ? 2.5 : 1.5,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: childWidget,
                );
              }),
            ),
          ),
        ),
      ],
    );
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
                  const Expanded(
                    child: Text(
                      'Lembrete Amigo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_pairedIdosoId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryContainer, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.link, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text(
                        'Celular Conectado',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pairedIdosoName ?? 'Idoso Conectado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _desvincular,
                          icon: const Icon(Icons.link_off, size: 24, color: Colors.white),
                          label: const Text(
                            'DESCONECTAR APARELHO',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                const Text(
                  'Conectar Celular do Idoso',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Insira o código de conexão de 6 dígitos que está sendo exibido na tela do idoso para vincular o dispositivo ao seu painel.',
                  style: TextStyle(fontSize: 18, height: 1.5, color: AppColors.onSurfaceVariant),
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
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.link, size: 28),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    label: Text(
                      _isLoading ? 'CONECTANDO...' : 'VINCULAR DISPOSITIVO',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
