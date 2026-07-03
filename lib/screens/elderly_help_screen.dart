import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/message_service.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ligarAjudante() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';
      final doc = await FirebaseFirestore.instance
          .collection('idosos')
          .doc(idosoId)
          .get();

      String phone = '';
      if (doc.exists) {
        phone = doc.data()?['telefone'] ?? '';
      }

      if (phone.isEmpty) {
        phone = '190';
      }

      final Uri launchUri = Uri(scheme: 'tel', path: phone);

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
    await TTSService.instance.parar(caller: this);
    bool isRecording = false;
    bool isPlaying = false;
    String? recordedFilePath;
    String statusMsg = 'Toque no microfone para começar';

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> startRecording() async {
              try {
                final tempDir = await getTemporaryDirectory();
                final path =
                    '${tempDir.path}/mensagem_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

                if (await _audioRecorder.hasPermission()) {
                  await _audioRecorder.start(
                    const RecordConfig(encoder: AudioEncoder.aacLc),
                    path: path,
                  );
                  setDialogState(() {
                    isRecording = true;
                    recordedFilePath = null;
                    statusMsg =
                        'Gravando áudio...\nToque no botão vermelho para parar';
                  });
                } else {
                  setDialogState(() {
                    isRecording = true;
                    recordedFilePath = null;
                    statusMsg = 'Gravando (Simulado)...';
                  });
                  Future.delayed(const Duration(seconds: 4), () async {
                    if (context.mounted && isRecording) {
                      final file = File(path);
                      await file.writeAsBytes([0, 1, 2, 3]);
                      setDialogState(() {
                        isRecording = false;
                        recordedFilePath = path;
                        statusMsg = 'Áudio gravado!';
                      });
                    }
                  });
                }
              } catch (e) {
                debugPrint('Erro ao iniciar gravacao de mensagem: $e');
                final tempDir = await getTemporaryDirectory();
                final path =
                    '${tempDir.path}/mensagem_audio_mock_${DateTime.now().millisecondsSinceEpoch}.m4a';
                final file = File(path);
                await file.writeAsBytes([0, 1, 2, 3]);
                setDialogState(() {
                  isRecording = false;
                  recordedFilePath = path;
                  statusMsg = 'Áudio gravado (Simulado)!';
                });
              }
            }

            Future<void> stopRecording() async {
              try {
                if (await _audioRecorder.isRecording()) {
                  final path = await _audioRecorder.stop();
                  setDialogState(() {
                    isRecording = false;
                    recordedFilePath = path;
                    statusMsg = 'Áudio gravado!\nToque no Play para ouvir.';
                  });
                } else {
                  setDialogState(() {
                    isRecording = false;
                  });
                }
              } catch (e) {
                debugPrint('Erro ao parar gravacao: $e');
                setDialogState(() {
                  isRecording = false;
                });
              }
            }

            Future<void> togglePlayback() async {
              if (recordedFilePath == null) return;

              if (isPlaying) {
                await _audioPlayer.stop();
                setDialogState(() => isPlaying = false);
              } else {
                setDialogState(() => isPlaying = true);
                _audioPlayer.onPlayerComplete.first.then((_) {
                  setDialogState(() => isPlaying = false);
                });
                try {
                  await _audioPlayer.play(
                    DeviceFileSource(recordedFilePath!),
                    volume: 1.0,
                  );
                } catch (e) {
                  debugPrint('Erro ao tocar gravacao: $e');
                  setDialogState(() => isPlaying = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Gravar Mensagem de Áudio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  if (!isRecording && recordedFilePath == null) ...[
                    GestureDetector(
                      onTap: startRecording,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic,
                          size: 56,
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ] else if (isRecording) ...[
                    GestureDetector(
                      onTap: stopRecording,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.stop,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else if (recordedFilePath != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: togglePlayback,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.stop : Icons.play_arrow,
                              size: 48,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: startRecording,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                            child: const Icon(
                              Icons.refresh,
                              size: 28,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    statusMsg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isRecording ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (isRecording) {
                      await _audioRecorder.stop();
                    }
                    if (isPlaying) {
                      await _audioPlayer.stop();
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (recordedFilePath != null)
                  ElevatedButton(
                    onPressed: () async {
                      if (isPlaying) {
                        await _audioPlayer.stop();
                      }
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final idosoId =
                            prefs.getString('paired_idoso_id') ?? 'joao';

                        String idosoName = 'Idoso';
                        final doc = await FirebaseFirestore.instance
                            .collection('idosos')
                            .doc(idosoId)
                            .get();
                        if (doc.exists) {
                          idosoName = doc.data()?['nome'] ?? 'Idoso';
                        }

                        await MessageService.instance.sendAudio(
                          audioPath: recordedFilePath!,
                          fallbackText: 'Mensagem de áudio enviada',
                          nomeIdoso: idosoName,
                        );

                        TTSService.instance.falar(
                          'Mensagem de áudio enviada com sucesso!',
                          caller: this,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mensagem de áudio enviada com sucesso!',
                              ),
                              backgroundColor: AppColors.tertiaryFixedDim,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Erro ao enviar mensagem de áudio: $e');
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                    ),
                    child: const Text(
                      'ENVIAR',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    _buildCallButton(context),
                    const SizedBox(height: 24),
                    _buildHeartRateCard(context),
                    const SizedBox(height: 24),
                    _buildSecondaryGrid(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 100,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Pedir ajuda',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  TTSService.instance.falar(
                    'Olá! Esta é a tela para pedir ajuda. Aqui você pode ligar para quem cuida de você apertando o grande botão verde, ver como está seu coração apertando o botão vermelho com o desenho de um coração, ou enviar um recado por áudio ou texto se precisar de qualquer outra coisa.',
                    caller: this,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Me explica',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              TTSService.instance.parar(caller: this);
              Navigator.pushNamed(context, '/elderly-profile');
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryContainer, width: 2),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primaryContainer,
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
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 20),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryGrid(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message, size: 36, color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'Mandar Recado',
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
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 36,
                        color: AppColors.primary,
                      ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  TTSService.instance.parar(caller: this);
                  Navigator.pushNamed(context, '/messages');
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum, size: 36, color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'Ver Recados',
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
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.home, 'Início', false, () {
                TTSService.instance.parar(caller: this);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/elderly-home',
                  (route) => false,
                );
              }),
              _bottomNavItem(Icons.list_alt, 'Lembretes', false, () {
                TTSService.instance.parar(caller: this);
                Navigator.pushNamed(context, '/all-reminders');
              }),
              _bottomNavItem(Icons.help_center, 'Ajuda', true, null),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      TTSService.instance.parar(caller: this);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AlexAssistantSheet(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AlexAvatar(size: 40, animate: false),
                          SizedBox(height: 2),
                          Text(
                            'Falar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback? onTap,
  ) {
    final itemColor = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: itemColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
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
            Navigator.pushNamed(
              context,
              '/heart-rate',
            ).then((_) => _loadLastBpm());
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.error, size: 56),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medir o Coração',
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
                            : 'Ver como está o seu coração usando a câmera do celular',
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
