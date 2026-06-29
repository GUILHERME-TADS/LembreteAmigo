import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/lembrete_service.dart';

class AdjustTaskScreen extends StatefulWidget {
  const AdjustTaskScreen({super.key});

  @override
  State<AdjustTaskScreen> createState() => _AdjustTaskScreenState();
}

class _AdjustTaskScreenState extends State<AdjustTaskScreen> {
  String _nomeIdoso = 'Não cadastrado';
  bool _isLoadingProfile = true;

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
    _loadProfile();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  @override
  void dispose() {
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    await LembreteService.instance.carregar();
    try {
      if (_useFirebase) {
        final prefs = await SharedPreferences.getInstance();
        final idosoId = prefs.getString('selected_idoso_id') ?? prefs.getString('paired_idoso_id') ?? 'joao';
        final doc = await FirebaseFirestore.instance
            .collection('idoso_perfil')
            .doc(idosoId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _nomeIdoso = doc.data()!['nome'] as String? ?? 'Não cadastrado';
              _isLoadingProfile = false;
            });
          }
          return;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('idoso_perfil');
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _nomeIdoso = data['nome'] as String? ?? 'Não cadastrado';
              _isLoadingProfile = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  void _adjustTime(String id, int currentHour, int currentMin) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMin),
      helpText: 'SELECIONE O HORÁRIO',
    );
    if (picked != null) {
      await LembreteService.instance.atualizarHorario(id, picked.hour, picked.minute);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horário atualizado com sucesso!'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = LembreteService.instance.lembretes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                        const Text('Ajustar Lembretes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(_nomeIdoso, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'LEMBRETES CADASTRADOS',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          if (list.isEmpty)
                            const Text(
                              'Nenhum lembrete cadastrado ainda.',
                              style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
                            )
                          else
                            ...list.map((lembrete) {
                              return _adjustableItem(lembrete.titulo, lembrete.horarioFormatado);
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AJUSTAR HORÁRIOS (TOQUE PARA ALTERAR)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: const Text(
                          'Adicione lembretes no painel para ajustar horários.',
                          style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          children: list.map((lembrete) {
                            final isLast = list.last.id == lembrete.id;
                            return Column(
                              children: [
                                _timeAdjuster(
                                  lembrete.titulo,
                                  lembrete.horarioFormatado,
                                  onTap: () => _adjustTime(lembrete.id, lembrete.horarioHour, lembrete.horarioMinute),
                                ),
                                if (!isLast) const Divider(height: 24),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryFixed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _adjustableItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.outline, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface))),
          Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _timeAdjuster(String title, String time, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, color: AppColors.onSurface))),
            const Icon(Icons.access_time, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
