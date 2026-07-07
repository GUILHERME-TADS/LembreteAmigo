import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/alex_voice_profile.dart';
import '../services/always_listening_service.dart';
import '../theme/app_theme.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late AlexVoiceProfile _profile;
  late AlexVoiceGender _selectedGender;
  late double _speechRate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = TTSService.instance.voiceProfile;
    _selectedGender = _profile.gender;
    _speechRate = _profile.speechRate;
  }

  Future<void> _testVoice() async {
    final testProfile = AlexVoiceProfile(
      gender: _selectedGender,
      speechRate: _speechRate,
      pitch: 1.0,
    );

    final tts = TTSService.instance;
    await tts.initFromProfile(testProfile);
    await tts.falarComEmocao(
      'Ola! Meu nome e Alex. Como posso ajudar voce hoje?',
      'informativo',
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final newProfile = AlexVoiceProfile(
      gender: _selectedGender,
      speechRate: _speechRate,
      pitch: 1.0,
    );

    await TTSService.instance.updateProfile(newProfile);
    await TTSService.instance.falarComEmocao(
      'Pronto! Voz atualizada.',
      'alegre',
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voz do Alex'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Escolha a voz do Alex',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione o timbre de voz que o Alex usara para falar com voce.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildAlwaysListeningToggle(),
          const SizedBox(height: 24),

          Text(
            'TIMBRE DA VOZ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildGenderOption(AlexVoiceGender.female, 'Feminino',
              'Voz feminina, suave e acolhedora'),
          const SizedBox(height: 8),
          _buildGenderOption(AlexVoiceGender.male, 'Masculino',
              'Voz masculina, firme e tranquila'),
          const SizedBox(height: 32),

          Text(
            'VELOCIDADE DA FALA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Devagar', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.25,
                  max: 0.7,
                  divisions: 9,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.outlineVariant,
                  label: _speechRate.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _speechRate = v),
                ),
              ),
              const Text('Rápido', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _testVoice,
              icon: const Icon(Icons.volume_up),
              label: const Text(
                'TESTAR VOZ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildAlwaysListeningToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Alex Sempre Ativo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AlwaysListeningService.instance.enabled,
                builder: (context, enabled, _) {
                  return Switch(
                    value: enabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      AlwaysListeningService.instance.setEnabled(v);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Alex vai escutar e responder comandos de voz sem precisar tocar na tela. Ex: "Alex, cadê meu remédio?"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ' Isso pode consumir mais bateria.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(AlexVoiceGender gender, String title, String subtitle) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              gender == AlexVoiceGender.female
                  ? Icons.female
                  : Icons.male,
              color: isSelected
                  ? AppColors.onPrimaryFixed
                  : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isSelected
                          ? AppColors.onPrimaryFixed
                          : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.onPrimaryFixedVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: AppColors.onPrimaryFixedVariant),
          ],
        ),
      ),
    );
  }
}
