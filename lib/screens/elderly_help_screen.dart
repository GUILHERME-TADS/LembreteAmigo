import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/message_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/session_role_service.dart';
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
  String _caregiverName = 'meu ajudante';
  String? _caregiverFoto;
  String? _ambulancePhone;
  bool _isPaired = false;

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
        'Se precisar de ajuda, aperte o botão de ligar para o seu ajudante.',
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        'Olá! Esta é a tela de ajuda. Para usar as funções de ligação e recados, você precisa de um cuidador conectado.',
        caller: this,
      );
    }
  }

  void _speakUnpairedWarning() {
    TTSService.instance.falar(
      'Esta opção precisa de um ajudante conectado. Por favor, peça para o seu ajudante conectar o celular dele ao seu.',
      caller: this,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Você precisa de um cuidador conectado para usar esta função.'),
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

      final isPaired = await SessionRoleService.isElderlyConnectedToSupervisor();

      if (mounted) {
        setState(() {
          _isPaired = isPaired;
        });
        _speakIntroVoice(isPaired);
      }
      final doc = await _getElderlyProfileDoc(idosoId);

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

  Future<DocumentSnapshot<Map<String, dynamic>>> _getElderlyProfileDoc(
    String idosoId,
  ) async {
    final profileDoc = await FirebaseFirestore.instance
        .collection('idoso_perfil')
        .doc(idosoId)
        .get();
    if (profileDoc.exists) return profileDoc;

    return FirebaseFirestore.instance.collection('idosos').doc(idosoId).get();
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
                    'VOLTAR',
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
                            prefs.getString('paired_idoso_id') ??
                            SessionRoleService.unpairedIdosoId;

                        String idosoName = 'Idoso';
                        final doc = await _getElderlyProfileDoc(idosoId);
                        if (doc.exists) {
                          idosoName = doc.data()?['nome'] ?? 'Idoso';
                        }

                        final sent = await MessageService.instance.sendAudio(
                          audioPath: recordedFilePath!,
                          fallbackText: 'Mensagem de áudio enviada',
                          nomeIdoso: idosoName,
                        );
                        if (!sent) {
                          throw StateError('Nenhum cuidador conectado para receber a mensagem.');
                        }

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
                      'ENVIAR RECADO',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
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
              const MeExplicaButton(
                textoExplicacao:
                    'Olá! Esta é a tela para pedir ajuda. Aqui você pode ligar para quem cuida de você apertando o grande botão amarelo com a foto de quem cuida de você, mandar um recado de voz se precisar de algo, ou usar os botões de emergência abaixo em caso de necessidade urgente.',
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              TTSService.instance.parar(caller: this);
              await Navigator.pushNamed(context, '/elderly-profile');
              _loadProfilePhoto();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(BuildContext context) {
    return Opacity(
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
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
                          border: Border.all(color: Colors.white, width: 6),
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
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(70),
                                  child: Image.network(
                                    _caregiverFoto!,
                                    width: 128,
                                    height: 128,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 80,
                                      color: AppColors.onPrimaryContainer,
                                    ),
                                  ),
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
  );
}

  Widget _buildSecondaryGrid(BuildContext context) {
    return Column(
      children: [
        // MANDAR / VER RECADOS (Lado a lado)
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
                      height: 120,
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
                          SizedBox(height: 8),
                          Text(
                            'Mandar\nRecado',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
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
                  color: const Color(0xFFE8F5E9), // Soft Green
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () {
                      if (!_isPaired) {
                        _speakUnpairedWarning();
                        return;
                      }
                      TTSService.instance.falar(
                        'Abrindo seus recados do cuidador.',
                        caller: this,
                      );
                      Navigator.pushNamed(context, '/messages');
                    },
                    child: Container(
                      height: 120,
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
                          Icon(Icons.chat_bubble, size: 36, color: Color(0xFF2E7D32)),
                          SizedBox(height: 8),
                          Text(
                            'Ver\nRecados',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
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
          ],
        ),
        const SizedBox(height: 24),

        // SEÇÃO DE SOS & EMERGÊNCIA
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning, color: AppColors.error, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'SOS - EMERGÊNCIA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Toque para pedir ajuda urgente:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // CHAMADA DE VOZ (APLICATIVO)
              Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: SeniorButton(
                  label: 'Chamada de Voz SOS',
                  icon: Icons.phone_in_talk,
                  backgroundColor: const Color(0xFF2E7D32), // Green
                  textColor: Colors.white,
                  onPressed: () {
                    if (!_isPaired) {
                      _speakUnpairedWarning();
                      return;
                    }
                    _initiateCall('voice');
                  },
                ),
              ),
              const SizedBox(height: 12),

              // CHAMADA DE VÍDEO (APLICATIVO)
              Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: SeniorButton(
                  label: 'Chamada de Vídeo SOS',
                  icon: Icons.videocam,
                  backgroundColor: const Color(0xFF1565C0), // Dark Blue
                  textColor: Colors.white,
                  onPressed: () {
                    if (!_isPaired) {
                      _speakUnpairedWarning();
                      return;
                    }
                    _initiateCall('video');
                  },
                ),
              ),
              const SizedBox(height: 12),

              // LIGAR PARA AMBULNCIA
              if (_ambulancePhone != null) ...[
              SeniorButton(
                label: 'Ligar para Ambulância',
                icon: Icons.local_hospital,
                backgroundColor: AppColors.error,
                textColor: Colors.white,
                onPressed: () {
                  _confirmarAcaoSOSComContagem(
                    'Ligar para Ambulância',
                    'Iniciando ligação para a ambulância',
                    () => _ligar(_ambulancePhone!),
                  );
                },
              ),
              const SizedBox(height: 12),
              ],

              // ENVIAR LOCALIZAÇÃO PARA O CHAT
              Opacity(
                opacity: _isPaired ? 1.0 : 0.4,
                child: SeniorButton(
                  label: 'Enviar Localização para o Chat',
                  icon: Icons.location_on,
                  backgroundColor: const Color(0xFF5E35B1), // Purple
                  textColor: Colors.white,
                  onPressed: () {
                    if (!_isPaired) {
                      _speakUnpairedWarning();
                      return;
                    }
                    _enviarLocalizacaoChat();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
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



  Future<void> _loadProfilePhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFoto = prefs.getString('idoso_foto_path');
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto no help: $e');
    }
  }



  void _confirmarAcaoSOSComContagem(
    String acaoTitulo,
    String ttsMensagem,
    VoidCallback acaoConfirmada,
  ) {
    _stopAllAudioAndTts();

    int segundosRestantes = 5;
    Timer? countdownTimer;

    TTSService.instance.falar(
      '$ttsMensagem em $segundosRestantes segundos. Aperte no botão para cancelar.',
      caller: this,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isHighContrast =
            Theme.of(context).colorScheme.primary == Colors.black;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (segundosRestantes > 1) {
                if (mounted) {
                  setDialogState(() {
                    segundosRestantes--;
                  });
                  TTSService.instance.falar('$segundosRestantes', caller: this);
                }
              } else {
                timer.cancel();
                Navigator.pop(context); // Fechar o diálogo
                acaoConfirmada(); // Executar a ação
              }
            });

            return AlertDialog(
              backgroundColor: isHighContrast
                  ? Colors.white
                  : AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: isHighContrast
                    ? const BorderSide(color: Colors.black, width: 4)
                    : BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.warning, color: AppColors.error, size: 36),
                      SizedBox(width: 12),
                      Text(
                        'ATENÇÃO',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    acaoTitulo.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isHighContrast ? Colors.black : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.error, width: 4),
                    ),
                    child: Center(
                      child: Text(
                        '$segundosRestantes',
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'O telefone fará a ação automaticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        countdownTimer?.cancel();
                        TTSService.instance.parar(caller: this);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, size: 36),
                      label: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHighContrast
                            ? Colors.black
                            : AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isHighContrast
                              ? const BorderSide(color: Colors.white, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      TTSService.instance.parar(caller: this);
    });
  }

  void _stopAllAudioAndTts() {
    TTSService.instance.parar(caller: this);
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }



  void _ligar(String numero) async {
    final Uri launchUri = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o discador.')),
        );
      }
    }
  }

  Future<void> _initiateCall(String callType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idosoId = prefs.getString('paired_idoso_id');
      if (idosoId == null || idosoId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum cuidador vinculado.')),
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
        );
      } else if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível iniciar chamada de $label.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final label = callType == 'voice' ? 'voz' : 'vídeo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar chamada de $label.')),
        );
      }
    }
  }

  void _enviarLocalizacaoChat() async {
    TTSService.instance.falar(
      'Estou buscando sua localização para enviar ao chat.',
      caller: this,
    );

    final location = await LocationService.instance.getCurrentSosLocation();
    final message = location.hasLocation
        ? 'SOS! Preciso de ajuda urgente. Minha localização: ${location.mapsUrl}'
        : 'SOS! Preciso de ajuda urgente. Não consegui obter minha localização automaticamente. ${location.errorMessage ?? ''}';

    try {
      final sent = await MessageService.instance.sendText(message);
      if (!sent) {
        throw StateError('Nenhum cuidador conectado para receber a localização.');
      }
      const feedback =
          'Localização enviada para o chat do supervisor com sucesso.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(feedback)),
        );
      }
      TTSService.instance.falar(feedback, caller: this);
    } catch (e) {
      final erroMsg = 'Erro ao enviar localização: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erroMsg)),
        );
      }
      TTSService.instance.falar('Não foi possível enviar a localização.', caller: this);
    }
  }
}
