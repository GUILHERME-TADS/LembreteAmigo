import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/alex_voice_profile.dart';
import '../services/always_listening_service.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late AlexVoiceProfile _profile;
  late double _speechRate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = TTSService.instance.voiceProfile;
    _speechRate = _profile.speechRate;
  }



  Future<void> _testVoice() async {
    try {
      final testProfile = AlexVoiceProfile(
        speechRate: _speechRate,
        pitch: 1.0,
      );

      final tts = TTSService.instance;
      await tts.initFromProfile(testProfile);
      await tts.falar(
        'Olá! Meu nome é Alex. Como posso ajudar você hoje?',
      );
    } catch (e) {
      debugPrint('Erro ao testar voz: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final newProfile = AlexVoiceProfile(
        speechRate: _speechRate,
        pitch: 1.0,
      );

      await TTSService.instance.updateProfile(newProfile);
      await TTSService.instance.falar(
        'Pronto! Voz atualizada.',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Erro ao salvar voz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui salvar a voz.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Widget _buildSpeedPreset(String label, String emoji, double rate) {
    final isSelected = (_speechRate - rate).abs() < 0.05;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _speechRate = rate;
          });
          _testVoice();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
              width: isSelected ? 3 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta é a tela da voz do Alex. Aqui você escolhe se ele fala devagar, normal ou rápido. Toque em Testar Voz para ouvir. Quando estiver bom, aperte Salvar.',
      ),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            TTSService.instance.parar(caller: this);
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        title: const Text(
          'Voz do Alex',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Ajuste a voz do Alex para ficar boa de ouvir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'VELOCIDADE DA VOZ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSpeedPreset('DEVAGAR', '🐢', 0.35),
                const SizedBox(width: 12),
                _buildSpeedPreset('NORMAL', '🗣️', 0.50),
                const SizedBox(width: 12),
                _buildSpeedPreset('RÁPIDO', '⚡', 0.65),
              ],
            ),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _testVoice,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'TESTAR VOZ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SALVAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
