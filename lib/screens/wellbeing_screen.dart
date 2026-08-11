import 'package:flutter/material.dart';
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como você está se sentindo?',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var value = 1; value <= 5; value++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        label: _moodLabel(value),
                        button: true,
                        selected: _mood == value,
                        child: InkWell(
                          onTap: () => setState(() => _mood = value),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 68,
                            decoration: BoxDecoration(
                              color: _mood == value
                                  ? AppColors.secondaryContainer
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _mood == value
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                                width: _mood == value ? 3 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _moodEmoji(value),
                              style: const TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Está sentindo alguma coisa?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final symptom in _symptomOptions)
                  FilterChip(
                    label: Text(symptom),
                    selected: _symptoms.contains(symptom),
                    onSelected: (selected) {
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
            const SizedBox(height: 18),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'Conte com suas palavras (opcional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _listening ? 'Parar ditado' : 'Falar',
                  onPressed: _toggleListening,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  color: _listening ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            CheckboxListTile(
              value: _needsHelp,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.error,
              title: const Text(
                'Preciso de ajuda',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Seu cuidador receberá um alerta quando houver conexão.',
              ),
              onChanged: (value) => setState(() => _needsHelp = value ?? false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle, size: 28),
                label: const Text(
                  'SALVAR COMO ESTOU',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(WellbeingEntry entry) {
    return Card(
      color: entry.needsHelp ? AppColors.errorContainer : AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Text(
          _moodEmoji(entry.mood),
          style: const TextStyle(fontSize: 36),
        ),
        title: Text(
          _moodLabel(entry.mood),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt.toLocal()),
            ),
            if (entry.symptoms.isNotEmpty)
              Text('Sintomas: ${entry.symptoms.join(', ')}'),
            if (entry.note.isNotEmpty) Text(entry.note),
            if (entry.needsHelp)
              const Text(
                'PEDIU AJUDA',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
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
