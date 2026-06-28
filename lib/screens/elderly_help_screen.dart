import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/index.dart';

class ElderlyHelpScreen extends StatefulWidget {
  const ElderlyHelpScreen({super.key});

  @override
  State<ElderlyHelpScreen> createState() => _ElderlyHelpScreenState();
}

class _ElderlyHelpScreenState extends State<ElderlyHelpScreen> {
  int? _lastBpm;
  String? _lastBpmTimeText;

  @override
  void initState() {
    super.initState();
    _loadLastBpm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Se precisar de ajuda, aperte o botão amarelo de ligar para o seu ajudante.',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  Future<void> _ligarAjudante() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';
      final doc = await FirebaseFirestore.instance.collection('idosos').doc(idosoId).get();
      
      String phone = '';
      if (doc.exists) {
        phone = doc.data()?['telefone'] ?? '';
      }
      
      if (phone.isEmpty) {
        phone = '190';
      }
      
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phone,
      );
      
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Não foi possível ligar para $phone';
      }
    } catch (e) {
      debugPrint('Erro ao ligar: $e');
    }
  }

  Future<void> _enviarMensagemDialog() async {
    final TextEditingController textController = TextEditingController();
    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;
    String statusMsg = 'Toque no microfone para ditar';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Enviar Mensagem',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 20, color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Digite aqui ou use a voz...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusMsg,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isListening ? AppColors.secondary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      if (isListening) {
                        await speech.stop();
                        setDialogState(() {
                          isListening = false;
                          statusMsg = 'Toque no microfone para ditar';
                        });
                      } else {
                        final available = await speech.initialize();
                        if (available) {
                          setDialogState(() {
                            isListening = true;
                            statusMsg = 'Ouvindo... Fale agora';
                          });
                          speech.listen(
                            onResult: (result) {
                              setDialogState(() {
                                textController.text = result.recognizedWords;
                                if (result.finalResult) {
                                  isListening = false;
                                  statusMsg = 'Toque no microfone para ditar';
                                }
                              });
                            },
                            listenOptions: stt.SpeechListenOptions(
                              localeId: 'pt_BR',
                            ),
                          );
                        } else {
                          setDialogState(() {
                            statusMsg = 'Microfone indisponível';
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isListening ? AppColors.secondaryContainer : AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        size: 40,
                        color: isListening ? AppColors.onSecondaryContainer : AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    speech.stop();
                    Navigator.pop(context);
                  },
                  child: const Text('CANCELAR', style: TextStyle(fontSize: 18, color: AppColors.error, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';
                        
                        String idosoName = 'Idoso';
                        final doc = await FirebaseFirestore.instance.collection('idosos').doc(idosoId).get();
                        if (doc.exists) {
                          idosoName = doc.data()?['nome'] ?? 'Idoso';
                        }
                        
                        await FirebaseFirestore.instance.collection('mensagens').add({
                          'idosoId': idosoId,
                          'nomeIdoso': idosoName,
                          'texto': text,
                          'criadoEm': FieldValue.serverTimestamp(),
                          'lido': false,
                        });
                        
                        TTSService.instance.falar('Mensagem enviada com sucesso!', caller: this);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensagem enviada com sucesso!'),
                              backgroundColor: AppColors.tertiaryFixedDim,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Erro ao enviar mensagem: $e');
                      }
                    }
                    speech.stop();
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiaryFixedDim),
                  child: const Text('ENVIAR', style: TextStyle(fontSize: 18, color: AppColors.onTertiaryFixed, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildVoiceBanner(context),
                    const SizedBox(height: 24),
                    _buildCallButton(context),
                    const SizedBox(height: 24),
                    _buildHeartRateCard(context),
                    const SizedBox(height: 24),
                    _buildSecondaryGrid(context),
                    const SizedBox(height: 24),
                    _buildSupportCard(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          TTSService.instance.parar(caller: this);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          'Voltar',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Text(
            'Pedir ajuda',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              TTSService.instance.falar(
                'Se precisar de ajuda, aperte o botão amarelo de ligar para o seu ajudante.',
                caller: this,
              );
            },
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.primaryContainer, width: 2),
              ),
            ),
            child: const Icon(Icons.person, color: AppColors.primaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: const Row(
        children: [
          Icon(Icons.record_voice_over, color: AppColors.onPrimaryContainer, size: 36),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              '"Aperte aqui para falar com Alex"',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _ligarAjudante,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.secondary, width: 4),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    const AlexAvatar(size: 160),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.secondaryContainer, width: 4),
                        ),
                        child: const Icon(Icons.call, color: AppColors.onSecondary, size: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ligar para meu ajudante',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Falar com Alex agora',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _enviarMensagemDialog,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.message, size: 36, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Enviar Mensagem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                TTSService.instance.parar(caller: this);
                Navigator.pushNamed(context, '/emergency-alert');
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.medical_services, size: 36, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Emergência',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.05,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suporte 24h',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Alex está disponível agora e pronto para ajudar com qualquer dúvida sobre seus remédios ou rotina.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                TTSService.instance.parar(caller: this);
                Navigator.pushNamedAndRemoveUntil(context, '/elderly-home', (route) => false);
              },
              child: _navItem(Icons.home, 'Início', false),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                TTSService.instance.parar(caller: this);
                Navigator.pushNamed(context, '/all-reminders');
              },
              child: _navItem(Icons.list_alt, 'Lembretes', false),
            ),
          ),
          Expanded(
            child: _navItem(Icons.help_center, 'Ajuda', true),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.secondaryContainer : null,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLastBpm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bpm = prefs.getInt('last_bpm_value');
      final timeStr = prefs.getString('last_bpm_time');
      if (bpm != null && timeStr != null) {
        final time = DateTime.parse(timeStr);
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        final day = time.day.toString().padLeft(2, '0');
        final month = time.month.toString().padLeft(2, '0');
        setState(() {
          _lastBpm = bpm;
          _lastBpmTimeText = '$day/$month às $hour:$minute';
        });
      }
    } catch (_) {}
  }

  Widget _buildHeartRateCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error, width: 3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () {
            TTSService.instance.parar(caller: this);
            Navigator.pushNamed(context, '/heart-rate').then((_) => _loadLastBpm());
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: AppColors.error,
                  size: 56,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medir Batimentos',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastBpm != null
                            ? 'Último: $_lastBpm BPM ($_lastBpmTimeText)'
                            : 'Veja seus batimentos cardíacos usando a câmera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
