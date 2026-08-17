import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/wellbeing_entry.dart';
import '../services/session_role_service.dart';
import '../services/tts_service.dart';
import '../services/wellbeing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/elderly_bottom_nav.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/supervisor_drawer.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  final _noteController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Set<String> _symptoms = {};
  String? _elderlyId;
  int _mood = 3;
  bool _needsHelp = false;
  bool _saving = false;
  bool _listening = false;

  static const _symptomOptions = [
    'Dor',
    'Tontura',
    'Enjoo',
    'Falta de ar',
    'Sono',
    'Sem apetite',
  ];

  @override
  void initState() {
    super.initState();
    _loadElderlyId();
  }

  @override
  void dispose() {
    _speech.stop();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadElderlyId() async {
    final id = await SessionRoleService.getActiveIdosoIdOrNull();
    if (mounted) setState(() => _elderlyId = id);
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ditado de voz indisponível.')),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'pt_BR',
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        _noteController.text = result.recognizedWords;
        _noteController.selection = TextSelection.collapsed(
          offset: _noteController.text.length,
        );
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WellbeingService.instance.addEntry(
        mood: _mood,
        symptoms: _symptoms.toList(growable: false),
        note: _noteController.text,
        needsHelp: _needsHelp,
      );
      final message = _needsHelp
          ? 'Registro salvo. Seu cuidador será avisado quando houver conexão.'
          : 'Pronto. Seu bem-estar foi registrado.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      await TTSService.instance.falar(message, caller: this);
      _noteController.clear();
      if (mounted) {
        setState(() {
          _mood = 3;
          _symptoms.clear();
          _needsHelp = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isElderly = SessionRoleService.isElderly;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isElderly
          ? null
          : const SupervisorDrawer(currentRoute: '/supervisor-wellbeing'),
      bottomNavigationBar: isElderly
          ? const ElderlyBottomNav(selected: ElderlyNavDestination.none)
          : const SupervisorBottomNav(selected: SupervisorNavDestination.none),
      appBar: AppBar(
        title: Text(isElderly ? 'Como estou hoje' : 'Diário de Bem-estar'),
      ),
      body: _elderlyId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<WellbeingEntry>>(
              stream: WellbeingService.instance.watchEntries(_elderlyId!),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <WellbeingEntry>[];
                return RefreshIndicator(
                  onRefresh: _loadElderlyId,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (isElderly) ...[
                        _checkInCard(),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        isElderly ? 'Registros recentes' : 'Linha do tempo',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.hasError)
                        Text('Não foi possível carregar: ${snapshot.error}')
                      else if (!snapshot.hasData)
                        const Center(child: CircularProgressIndicator())
                      else if (entries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ainda não há registros de bem-estar.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final entry in entries) ...[
                          _entryCard(entry),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _checkInCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.onPrimaryContainer,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Como você está hoje?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var value = 1; value <= 5; value++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        label: _moodLabel(value),
                        button: true,
                        selected: _mood == value,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _mood = value);
                            TTSService.instance.falar(_moodLabel(value));
                          },
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 84,
                            decoration: BoxDecoration(
                              color: _mood == value
                                  ? (value >= 4
                                      ? AppColors.successContainer
                                      : value == 3
                                          ? AppColors.warningContainer
                                          : AppColors.errorContainer)
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: _mood == value
                                    ? (value >= 4
                                        ? AppColors.success
                                        : value == 3
                                            ? AppColors.warning
                                            : AppColors.error)
                                    : AppColors.outlineVariant.withValues(alpha: 0.6),
                                width: _mood == value ? 3.0 : 1.5,
                              ),
                              boxShadow: _mood == value
                                  ? [
                                      BoxShadow(
                                        color: (value >= 4
                                                ? AppColors.success
                                                : value == 3
                                                    ? AppColors.warning
                                                    : AppColors.error)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _moodEmoji(value),
                                  style: TextStyle(
                                    fontSize: _mood == value ? 38 : 30,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _moodShortName(value),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _mood == value ? FontWeight.w900 : FontWeight.w600,
                                    color: _mood == value
                                        ? AppColors.onSurface
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Está sentindo alguma coisa?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final symptom in _symptomOptions)
                  FilterChip(
                    avatar: Icon(_symptomIcon(symptom), size: 18),
                    label: Text(
                      symptom,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    selected: _symptoms.contains(symptom),
                    selectedColor: AppColors.secondaryContainer,
                    checkmarkColor: AppColors.onSecondaryContainer,
                    backgroundColor: AppColors.surfaceContainerLow,
                    onSelected: (selected) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (selected) {
                          _symptoms.add(symptom);
                        } else {
                          _symptoms.remove(symptom);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'Conte com suas palavras (opcional)',
                labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                suffixIcon: IconButton(
                  tooltip: _listening ? 'Parar ditado' : 'Falar',
                  onPressed: _toggleListening,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  color: _listening ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _needsHelp ? AppColors.errorContainer.withValues(alpha: 0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: CheckboxListTile(
                value: _needsHelp,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                activeColor: AppColors.error,
                title: const Text(
                  'Preciso de ajuda com a saúde',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Seu cuidador receberá um aviso no painel dele.',
                  style: TextStyle(fontSize: 14),
                ),
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _needsHelp = value ?? false);
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 28),
                label: const Text(
                  'SALVAR COMO ESTOU',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(WellbeingEntry entry) {
    final isCritical = entry.needsHelp;
    return Container(
      decoration: BoxDecoration(
        color: isCritical ? AppColors.errorContainer.withValues(alpha: 0.35) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCritical ? AppColors.error.withValues(alpha: 0.4) : AppColors.outlineVariant.withValues(alpha: 0.6),
          width: isCritical ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _moodEmoji(entry.mood),
            style: const TextStyle(fontSize: 32),
          ),
        ),
        title: Text(
          _moodLabel(entry.mood),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy às HH:mm').format(entry.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (entry.symptoms.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Sintomas: ${entry.symptoms.join(', ')}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.note,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
            if (entry.needsHelp) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PEDIU AJUDA 🚨',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _symptomIcon(String symptom) {
    switch (symptom.toLowerCase()) {
      case 'dor':
        return Icons.healing;
      case 'tontura':
        return Icons.rotate_right;
      case 'enjoo':
        return Icons.sick;
      case 'falta de ar':
        return Icons.air;
      case 'sono':
        return Icons.bedtime;
      case 'sem apetite':
        return Icons.no_food;
      default:
        return Icons.health_and_safety;
    }
  }

  String _moodShortName(int value) {
    return const ['Mal', 'Ruim', 'Neutro', 'Bem', 'Ótimo'][value.clamp(1, 5) - 1];
  }

  String _moodEmoji(int value) {
    return const ['😢', '😟', '😐', '🙂', '😊'][value.clamp(1, 5) - 1];
  }

  String _moodLabel(int value) {
    return const [
      'Muito mal',
      'Não estou bem',
      'Mais ou menos',
      'Estou bem',
      'Estou muito bem',
    ][value.clamp(1, 5) - 1];
  }
}
