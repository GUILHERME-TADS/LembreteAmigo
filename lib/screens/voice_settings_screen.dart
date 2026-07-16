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
  bool _alwaysListeningEnabled = false;
  bool _loadingListeningSetting = true;

  @override
  void initState() {
    super.initState();
    _profile = TTSService.instance.voiceProfile;
    _speechRate = _profile.speechRate;
    _loadListeningSetting();
  }

  Future<void> _loadListeningSetting() async {
    await AlwaysListeningService.instance.initialize();
    if (!mounted) return;
    setState(() {
      _alwaysListeningEnabled = AlwaysListeningService.instance.enabled.value;
      _loadingListeningSetting = false;
    });
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
          const SnackBar(content: Text('Não foi possível salvar a voz.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Voz do Alex'),
            SizedBox(height: 6),
            MeExplicaButton(
              textoExplicacao:
                  'Olá! Esta é a tela de voz do Alex. Aqui você pode regular a velocidade em que ele fala. Arraste a barra para o lado esquerdo se quiser que ele fale mais devagar, ou para o lado direito se quiser que fale mais rápido. Toque no botão de "Testar Voz" para ouvir como ficou e depois aperte em "Salvar" quando terminar.',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Ajuste as configurações de áudio do Alex para o idoso.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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
                    onChanged: (val) {
                      setState(() {
                        _speechRate = val;
                      });
                    },
                  ),
                ),
                const Text('Rápido', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.outlineVariant),
            const SizedBox(height: 24),
            Text(
              'ESCUTA DO ALEX',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text(
                'Escuta Ativa (Falar "Alex")',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              subtitle: const Text(
                'Permite chamar o assistente dizendo "Alex" para ouvir e registrar lembretes por voz.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              value: _alwaysListeningEnabled,
              activeColor: AppColors.primary,
              onChanged: _loadingListeningSetting
                  ? null
                  : (bool value) async {
                      final success = await AlwaysListeningService.instance
                          .setEnabled(value);
                      if (mounted) {
                        setState(() {
                          _alwaysListeningEnabled =
                              AlwaysListeningService.instance.enabled.value;
                        });
                        if (value && !success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nao foi possivel ativar a escuta. Verifique a permissao do microfone e do reconhecimento de fala.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
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
