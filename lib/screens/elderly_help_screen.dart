import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/message_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/session_role_service.dart';
import '../services/elderly_profile_repository.dart';
import '../services/tts_service.dart';
import '../services/location_service.dart';
import '../services/video_call_service.dart';
import '../widgets/index.dart';

class ElderlyHelpScreen extends StatefulWidget {
  const ElderlyHelpScreen({super.key});

  @override
  State<ElderlyHelpScreen> createState() => _ElderlyHelpScreenState();
}

class _ElderlyHelpScreenState extends State<ElderlyHelpScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _fotoPath;
  String _caregiverName = 'meu cuidador';
  String? _caregiverFoto;
  String? _ambulancePhone;
  bool _isPaired = false;
  bool _isSendingLocation = false;
  bool _isMessageDialogOpen = false;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
    _loadCaregiverInfo();
    _loadAmbulancePhone();
  }

  Future<void> _loadAmbulancePhone() async {
    final phone = await EmergencyContactService.instance.getAmbulancePhone();
    if (mounted) {
      setState(() => _ambulancePhone = phone);
    }
  }

  void _speakIntroVoice(bool isPaired) {
    if (isPaired) {
      TTSService.instance.falar(
        'Se precisar de ajuda, aperte o botão de ligar para o seu cuidador.',
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        'Olá! Esta é a tela de ajuda. Para ligar, mandar recado ou pedir socorro, você precisa de um cuidador conectado.',
        caller: this,
      );
    }
  }

  void _speakUnpairedWarning() {
    TTSService.instance.falar(
      'Esta opção precisa de um cuidador conectado. Por favor, peça para o seu cuidador conectar o celular dele ao seu.',
      caller: this,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Você precisa de um cuidador conectado para usar esta função.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _loadCaregiverInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId =
          prefs.getString('paired_idoso_id') ??
          SessionRoleService.unpairedIdosoId;

      final isPaired =
          await SessionRoleService.isElderlyConnectedToSupervisor();

      if (mounted) {
        setState(() {
          _isPaired = isPaired;
        });
        _speakIntroVoice(isPaired);
      }
      final doc = await ElderlyProfileRepository.instance.getDocument(idosoId);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final supervisorId = data['supervisorId'];

        if (supervisorId != null) {
          final supDoc = await FirebaseFirestore.instance
              .collection('supervisores')
              .doc(supervisorId)
              .get();
          if (supDoc.exists && supDoc.data() != null) {
            final supData = supDoc.data()!;
            final name = supData['nome'] as String? ?? '';
            final foto = supData['fotoPath'] as String?;
            if (mounted) {
              setState(() {
                if (name.isNotEmpty) {
                  _caregiverName = name.split(' ').first;
                }
                _caregiverFoto = foto;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar cuidador: $e');
    }
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
      TTSService.instance.falar(
        'Ligando para $_caregiverName agora.',
        caller: this,
      );
      await _initiateCall('voice');
    } catch (e) {
      debugPrint('Erro ao ligar: $e');
    }
  }

  Future<void> _enviarMensagemDialog() async {
    if (_isMessageDialogOpen) return;
    _isMessageDialogOpen = true;
    await TTSService.instance.parar();
    bool isRecording = false;
    bool isPlaying = false;
    bool isBusy = false;
    bool isSending = false;
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
              if (isBusy || isSending || isRecording) return;
              await TTSService.instance.parar();
              isBusy = true;
              setDialogState(() {});
              try {
                final tempDir = await getTemporaryDirectory();
                final path =
                    '${tempDir.path}/mensagem_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

                if (await _audioRecorder.hasPermission()) {
                  await _audioRecorder.start(
                    const RecordConfig(
                      encoder: AudioEncoder.aacLc,
                      autoGain: true,
                      echoCancel: true,
                      noiseSuppress: true,
                    ),
                    path: path,
                  );
                  setDialogState(() {
                    isRecording = true;
                    recordedFilePath = null;
                    statusMsg =
                        'Gravando recado de voz...\nToque no botão vermelho para parar';
                  });
                } else {
                  setDialogState(() {
                    isRecording = true;
                    recordedFilePath = null;
                    statusMsg = 'Gravando...';
                  });
                  Future.delayed(const Duration(seconds: 4), () async {
                    if (context.mounted && isRecording) {
                      final file = File(path);
                      await file.writeAsBytes([0, 1, 2, 3]);
                      setDialogState(() {
                        isRecording = false;
                        recordedFilePath = path;
                        statusMsg = 'Recado gravado!';
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
                  statusMsg = 'Recado gravado!';
                });
              } finally {
                isBusy = false;
                if (context.mounted) setDialogState(() {});
              }
            }

            Future<void> stopRecording() async {
              if (isBusy || isSending || !isRecording) return;
              isBusy = true;
              setDialogState(() {});
              try {
                if (await _audioRecorder.isRecording()) {
                  final path = await _audioRecorder.stop();
                  setDialogState(() {
                    isRecording = false;
                    recordedFilePath = path;
                    statusMsg = 'Recado gravado!\nToque no botão de ouvir.';
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
              } finally {
                isBusy = false;
                if (context.mounted) setDialogState(() {});
              }
            }

            Future<void> togglePlayback() async {
              if (recordedFilePath == null || isBusy || isSending) return;
              isBusy = true;
              setDialogState(() {});

              try {
                if (isPlaying) {
                  await _audioPlayer.stop();
                  setDialogState(() => isPlaying = false);
                } else {
                  setDialogState(() => isPlaying = true);
                  _audioPlayer.onPlayerComplete.first.then((_) {
                    if (context.mounted) {
                      setDialogState(() => isPlaying = false);
                    }
                  });
                  await _audioPlayer.play(
                    DeviceFileSource(recordedFilePath!),
                    volume: 1.0,
                  );
                }
              } catch (e) {
                debugPrint('Erro ao tocar gravacao: $e');
                if (context.mounted) setDialogState(() => isPlaying = false);
              } finally {
                isBusy = false;
                if (context.mounted) setDialogState(() {});
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Gravar recado de voz',
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
                      onTap: isBusy || isSending ? null : startRecording,
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
                      onTap: isBusy || isSending ? null : stopRecording,
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
                          onTap: isBusy || isSending ? null : togglePlayback,
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
                          onTap: isBusy || isSending ? null : startRecording,
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
                  onPressed: isSending || isBusy
                      ? null
                      : () async {
                          if (isSending || isBusy) return;
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
                    'Voltar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (recordedFilePath != null)
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            if (isSending) return;
                            isSending = true;
                            setDialogState(() {});
                            if (isPlaying) {
                              await _audioPlayer.stop();
                            }
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              String idosoName = 'Idoso';
                              final jsonStr = prefs.getString('idoso_perfil');
                              if (jsonStr != null) {
                                try {
                                  final map = jsonDecode(jsonStr);
                                  if (map is Map && map['nome'] != null) {
                                    idosoName = map['nome'].toString();
                                  }
                                } catch (_) {}
                              }

                              final sent = await MessageService.instance
                                  .sendAudio(
                                    audioPath: recordedFilePath!,
                                    fallbackText: 'Recado de voz enviado',
                                    nomeIdoso: idosoName,
                                  );
                              if (!sent) {
                                throw StateError(
                                  'Nenhum cuidador conectado para receber a mensagem.',
                                );
                              }

                              TTSService.instance.falar(
                                'Recado de voz enviado.',
                                caller: this,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recado de voz enviado.'),
                                    backgroundColor: AppColors.tertiaryFixedDim,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint(
                                'Erro ao enviar mensagem de áudio: $e',
                              );
                            }
                            if (context.mounted) {
                              isSending = false;
                              setDialogState(() {});
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                    ),
                    child: const Text(
                      'Enviar recado',
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
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _isMessageDialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta é a tela para pedir ajuda. Aqui você pode ligar para o seu cuidador, mandar recado de voz, ouvir recados, fazer ligação com imagem, ligar para a ambulância ou mandar onde você está.',
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    _buildCallButton(context),
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
      bottomNavigationBar: const ElderlyBottomNav(
        selected: ElderlyNavDestination.help,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Pedir ajuda',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              if (_isProcessingAction) return;
              setState(() => _isProcessingAction = true);
              try {
                TTSService.instance.parar(caller: this);
                await Navigator.pushNamed(context, '/elderly-profile');
                _loadProfilePhoto();
              } finally {
                if (mounted) setState(() => _isProcessingAction = false);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(BuildContext context) {
    return Column(
      children: [
        Opacity(
          opacity: _isPaired ? 1.0 : 0.4,
          child: SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  if (!_isPaired) {
                    _speakUnpairedWarning();
                    return;
                  }
                  _ligarAjudante();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.secondary, width: 4),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 6,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child:
                                    _caregiverFoto != null &&
                                        _caregiverFoto!.isNotEmpty
                                    ? ElderlyProfileAvatar(
                                        fotoPath: _caregiverFoto,
                                        size: 128,
                                        borderWidth: 0,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 80,
                                        color: AppColors.onPrimaryContainer,
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2E7D32), // Green
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ligar para $_caregiverName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: Material(
                  color: const Color(0xFFE8F5E9), // Soft Green
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () {
                      if (!_isPaired) {
                        _speakUnpairedWarning();
                        return;
                      }
                      _initiateCall('video');
                    },
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF2E7D32),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.videocam,
                            size: 36,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Ligação\ncom Imagem',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E7D32),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: Material(
                  color: const Color(0xFFF3E5F5), // Soft Purple
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: _isSendingLocation
                        ? null
                        : () {
                            if (!_isPaired) {
                              _speakUnpairedWarning();
                              return;
                            }
                            _enviarLocalizacaoChat();
                          },
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF7B1FA2),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.location_on,
                            size: 36,
                            color: Color(0xFF7B1FA2),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Dizer onde\nestou',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7B1FA2),
                              height: 1.1,
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
      ],
    );
  }

  Widget _buildSecondaryGrid(BuildContext context) {
    return Column(
      children: [
        // MENSAGENS E RECADOS (Lado a lado - Azul)
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: Material(
                  color: const Color(0xFFE3F2FD), // Soft Blue
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () {
                      if (!_isPaired) {
                        _speakUnpairedWarning();
                        return;
                      }
                      TTSService.instance.falar(
                        'Diga o seu recado depois de tocar no botão.',
                        caller: this,
                      );
                      _enviarMensagemDialog();
                    },
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF1565C0),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.mic, size: 36, color: Color(0xFF1565C0)),
                          SizedBox(height: 6),
                          Text(
                            'Falar\nRecado',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1565C0),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: Material(
                  color: const Color(0xFFE3F2FD), // Soft Blue
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () async {
                      if (_isProcessingAction) return;
                      if (!_isPaired) {
                        _speakUnpairedWarning();
                        return;
                      }
                      setState(() => _isProcessingAction = true);
                      try {
                        await TTSService.instance.falar(
                          'Abrindo os recados do seu cuidador.',
                          caller: this,
                        );
                        if (context.mounted) {
                          await Navigator.pushNamed(context, '/messages');
                        }
                      } finally {
                        if (mounted) setState(() => _isProcessingAction = false);
                      }
                    },
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF1565C0),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MessageUnreadBadge(
                            child: Icon(
                              Icons.chat_bubble,
                              size: 36,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ouvir\nRecados',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1565C0),
                              height: 1.1,
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
        const SizedBox(height: 24),

        // CASO DE EMERGÊNCIA (Vermelho)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE), // Soft Red
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.error, width: 4),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Caso de Emergência',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final bool hasAmbulance =
                      _ambulancePhone != null &&
                      _ambulancePhone!.trim().isNotEmpty;

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 72,
                        child: ElevatedButton.icon(
                          onPressed: hasAmbulance
                              ? () async {
                                  await TTSService.instance.falar(
                                    'Iniciando ligação para a ambulância',
                                    caller: this,
                                  );
                                  _ligar(_ambulancePhone!.trim());
                                }
                              : _abrirDialogoConfigurarAmbulancia,
                          icon: const Icon(
                            Icons.local_hospital,
                            size: 32,
                            color: Colors.white,
                          ),
                          label: Text(
                            hasAmbulance
                                ? 'Ligar para Ambulância'
                                : 'Configurar Ambulância',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      if (!hasAmbulance) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Toque acima para adicionar o número',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _abrirDialogoConfigurarAmbulancia,
                          icon: const Icon(Icons.edit, size: 20, color: AppColors.error),
                          label: const Text(
                            'Editar número',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.error,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDialogoConfigurarAmbulancia() async {
    final controller = TextEditingController(text: _ambulancePhone ?? '');
    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;
    
    // Anuncia imediatamente ao abrir
    TTSService.instance.falar(
      'Por favor, digite o número da ambulância local ou aperte no microfone para falar o número.',
      caller: this,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: AppColors.background,
              title: const Text(
                'Número da Ambulância',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Digite o número da ambulância da sua região (exemplo: 192).',
                    style: TextStyle(fontSize: 18, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SeniorInputField(
                    label: 'Ambulância',
                    placeholder: '192',
                    prefixIcon: Icons.local_hospital,
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [AmbulancePhoneInputFormatter()],
                    isListening: isListening,
                    onTapAudio: () {
                      TTSService.instance.falar(
                        'Digite o número da ambulância local ou aperte no microfone para ditar o número em voz alta.',
                        caller: this,
                      );
                    },
                    onTapMic: () async {
                      await TTSService.instance.parar(caller: this);
                      if (isListening) {
                        await speech.stop();
                        SystemSound.play(SystemSoundType.click);
                        setDialogState(() => isListening = false);
                        return;
                      }
                      try {
                        final available = await speech.initialize(
                          onError: (e) {
                            if (isListening) SystemSound.play(SystemSoundType.click);
                            setDialogState(() => isListening = false);
                          },
                          onStatus: (status) {
                            if (status == stt.SpeechToText.doneStatus || status == stt.SpeechToText.notListeningStatus) {
                              if (isListening) SystemSound.play(SystemSoundType.click);
                              setDialogState(() => isListening = false);
                            }
                          },
                        );
                        if (available) {
                          setDialogState(() => isListening = true);
                          SystemSound.play(SystemSoundType.click);
                          speech.listen(
                            listenOptions: stt.SpeechListenOptions(
                              listenMode: stt.ListenMode.dictation,
                              localeId: 'pt_BR',
                            ),
                            onResult: (result) {
                              String text = result.recognizedWords;
                              text = text.replaceAll(RegExp(r'\D'), '');
                              final formatter = AmbulancePhoneInputFormatter();
                              final formattedValue = formatter.formatEditUpdate(
                                TextEditingValue.empty,
                                TextEditingValue(text: text),
                              );
                              controller.value = formattedValue;
                              if (result.finalResult) {
                                if (isListening) SystemSound.play(SystemSoundType.click);
                                setDialogState(() => isListening = false);
                                if (controller.text.isNotEmpty) {
                                  TTSService.instance.falar('Anotado: ${controller.text}', caller: this);
                                }
                              }
                            },
                          );
                        } else {
                          TTSService.instance.falar('Não consegui ouvir sua voz neste celular.', caller: this);
                        }
                      } catch (e) {
                        setDialogState(() => isListening = false);
                      }
                    },
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () {
                    TTSService.instance.parar(caller: this);
                    if (isListening) speech.stop();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    TTSService.instance.parar(caller: this);
                    if (isListening) speech.stop();
                    final num = controller.text.trim();
                    if (num.isNotEmpty) {
                      await EmergencyContactService.instance.saveAmbulancePhone(num);
                      if (mounted) {
                        setState(() {
                          _ambulancePhone = num;
                        });
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Salvar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final localFoto =
          await ElderlyProfileRepository.instance.getCachedPhotoPath();
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto no help: $e');
    }
  }

  void _ligar(String numero) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: numero);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não consegui abrir a ligação no celular.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _initiateCall(String callType) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id');
      if (idosoId == null || idosoId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum cuidador conectado.')),
          );
        }
        return;
      }
      final callStart = await VideoCallService.instance.initiateCall(
        idosoId: idosoId,
        initiatedBy: 'sos',
        callType: callType,
      );
      if (callStart != null && mounted) {
        await VideoCallService.instance.joinCall(
          callStart.roomName,
          callType: callType,
          callId: callStart.callId,
          alreadyVerified: true,
        );
      } else if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui começar a ligação de $label.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui começar a ligação de $label.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _enviarLocalizacaoChat() async {
    if (_isSendingLocation) return;
    setState(() => _isSendingLocation = true);
    TTSService.instance.falar(
      'Estou vendo onde você está para avisar o seu cuidador.',
      caller: this,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String nome = 'O IDOSO';
      final jsonStr = prefs.getString('idoso_perfil');
      if (jsonStr != null) {
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final n = data['nome'] as String?;
          if (n != null && n.trim().isNotEmpty && n != 'Não cadastrado') {
            nome = n.trim().toUpperCase();
          }
        } catch (_) {}
      }

      final location = await LocationService.instance.getCurrentSosLocation();
      bool sent;
      if (location.hasLocation && location.mapsUrl != null) {
        sent = await MessageService.instance.sendLocation(
          'ATENÇÃO CUIDADOR: $nome ACABOU DE ENVIAR SUA LOCALIZAÇÃO ATUAL NO MAPA!',
          location.mapsUrl!,
        );
      } else {
        final message =
            'ATENÇÃO CUIDADOR: $nome ACABOU DE PEDIR AJUDA URGENTE, MAS NÃO FOI POSSÍVEL OBTER A LOCALIZAÇÃO PELO CELULAR. ${location.errorMessage ?? ''}';
        sent = await MessageService.instance.sendText(message);
      }

      if (!sent) {
        throw StateError(
          'Nenhum cuidador conectado para receber a localização.',
        );
      }
      const feedback = 'Pronto. Enviei onde você está para o seu cuidador.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(feedback)));
      }
      TTSService.instance.falar(feedback, caller: this);
    } catch (e) {
      const erroMsg = 'Não consegui mandar onde você está. Tente de novo.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erroMsg)));
      }
      TTSService.instance.falar(
        'Não consegui mandar onde você está.',
        caller: this,
      );
    } finally {
      if (mounted) setState(() => _isSendingLocation = false);
    }
  }
}

class AmbulancePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length < oldValue.text.length) {
      return newValue;
    }
    final clean = text.replaceAll(RegExp(r'\D'), '');
    
    // Se for um número de emergência curto (3 a 4 dígitos, como 192, 193) não coloca parênteses
    if (clean.length <= 4) {
      return TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    
    // Formata no padrão de telefone/celular: (XX) XXXXX-XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7 && clean.length > 10) {
        buffer.write('-');
      } else if (i == 6 && clean.length <= 10) {
        buffer.write('-');
      }
      if (i < 11) buffer.write(clean[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
