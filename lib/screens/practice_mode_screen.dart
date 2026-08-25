import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';

import '../services/tts_service.dart';
import '../services/vibration_service.dart';
import '../theme/app_theme.dart';
import '../utils/period_helper.dart';

enum _TrainingStage {
  alarm,
  photoViewfinder,
  photoPreview,
  takenConfirmation,
  postponeConfirmation,
  helpConfirmation,
  voicePractice,
  videoCallPractice,
  celebration,
}

class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  _TrainingStage _stage = _TrainingStage.alarm;
  int _step = 0; // 0: já tomei (simples), 1: foto comprovante, 2: adiar, 3: pedir ajuda
  int _selectedMinutes = 10;
  bool _freeMode = false;
  bool _isPhotoFlowActive = false;

  // Câmera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashActive = false;
  XFile? _capturedPhoto;

  // Voz & Vídeo
  bool _isVoiceListening = false;
  bool _voiceConfirmed = false;
  bool _videoCallAnswered = false;

  static const _stepInstructions = [
    'Passo 1 de 6: Confirmação Simples. Toque no botão verde "JÁ TOMEI" para praticar.',
    'Passo 2 de 6: Foto do Remédio. Pratique como tirar a foto do remédio quando o cuidador pedir comprovação.',
    'Passo 3 de 6: Adiamento. Toque no botão amarelo "LEMBRAR MAIS TARDE" se não puder tomar agora.',
    'Passo 4 de 6: Pedido de Ajuda. Toque no botão vermelho "PRECISO DE AJUDA" para avisar o cuidador.',
    'Passo 5 de 6: Assistente Alex por Voz. Toque no microfone e diga "Já tomei meu remédio" para confirmar falando.',
    'Passo 6 de 6: Chamada de Vídeo. Veja como atender quando seu cuidador ou médico ligar para você.',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _initCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentStage();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        final controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();
        if (mounted) {
          setState(() {
            _cameraController = controller;
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Câmera no modo treino (modo simulado ativo): $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _cameraController?.dispose();
    TTSService.instance.parar(caller: this);
    VibrationService.stopVibration();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await TTSService.instance.parar(caller: this);
    if (!mounted) return;
    await TTSService.instance.falar(text, caller: this);
  }

  void _speakCurrentStage() {
    switch (_stage) {
      case _TrainingStage.alarm:
        if (_freeMode) {
          _speak(
            'Modo Livre de Treino. Toque em qualquer botão para ver o que acontece.',
          );
        } else if (_step == 1) {
          _speak(
            'Passo 2 de 4: Foto do Remédio. Alguns remédios exigem foto comprovante. Toque no botão verde "JÁ TOMEI (COM FOTO)" para abrir a câmera.',
          );
        } else {
          _speak(_stepInstructions[_step]);
        }
        break;
      case _TrainingStage.photoViewfinder:
        _speak(
          'Coloque a caixinha do remédio na frente do celular e aperte no botão redondo branco para tirar a foto.',
        );
        break;
      case _TrainingStage.photoPreview:
        _speak(
          'A foto foi tirada! Se ela ficou boa e nítida, aperte o botão verde FICOU BOA com o dedão para cima. Se ficou escura ou embaçada, aperte o botão vermelho FICOU RUIM para repetir.',
        );
        break;
      case _TrainingStage.takenConfirmation:
        if (_isPhotoFlowActive) {
          _speak(
            'Excelente! Sua foto foi aprovada e enviada para o cuidador. Remédio confirmado com sucesso!',
          );
        } else {
          _speak(
            'Muito bem! Você confirmou que tomou o remédio. Parabéns por cuidar da sua saúde!',
          );
        }
        break;
      case _TrainingStage.postponeConfirmation:
        _speak(
          'Combinado! O lembrete foi adiado para daqui a $_selectedMinutes minutos. Quando você não puder tomar na hora, o aplicativo vai tocar novamente depois.',
        );
        break;
      case _TrainingStage.helpConfirmation:
        _speak(
          'Tudo bem, não se preocupe! O aviso de ajuda foi enviado para o seu cuidador.',
        );
        break;
      case _TrainingStage.voicePractice:
        _speak(
          'Passo 5 de 6: Assistente Alex por Voz. Toque no microfone azul no centro e diga "Já tomei meu remédio".',
        );
        break;
      case _TrainingStage.videoCallPractice:
        _speak(
          'Passo 6 de 6: Chamada de Vídeo. Quando seu cuidador ligar, toque no botão verde grande ATENDER.',
        );
        break;
      case _TrainingStage.celebration:
        _speak(
          'Parabéns! Você concluiu todo o treinamento do aplicativo com sucesso! Agora você já sabe como confirmar por botão, tirar foto, adiar, pedir ajuda, usar comandos de voz e atender chamadas.',
        );
        break;
    }
  }

  // --- Handlers de Ações Simuladas ---

  void _onPressTaken() {
    VibrationService.gentleFeedback();
    if (!_freeMode && _step == 1) {
      // Passo da foto
      setState(() {
        _isPhotoFlowActive = true;
        _stage = _TrainingStage.photoViewfinder;
      });
      _speakCurrentStage();
      return;
    }

    setState(() {
      _isPhotoFlowActive = false;
      _stage = _TrainingStage.takenConfirmation;
    });
    _speakCurrentStage();
  }

  void _onPressTakenWithPhoto() {
    VibrationService.gentleFeedback();
    setState(() {
      _isPhotoFlowActive = true;
      _stage = _TrainingStage.photoViewfinder;
    });
    _speakCurrentStage();
  }

  Future<void> _capturePhoto() async {
    VibrationService.gentleFeedback();
    setState(() => _isFlashActive = true);

    XFile? file;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        file = await _cameraController!.takePicture();
      } catch (e) {
        debugPrint('Erro ao capturar foto no treino: $e');
      }
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _isFlashActive = false;
        _capturedPhoto = file;
        _stage = _TrainingStage.photoPreview;
      });
      _speakCurrentStage();
    });
  }

  void _retakePhoto() {
    VibrationService.gentleFeedback();
    setState(() {
      _capturedPhoto = null;
      _stage = _TrainingStage.photoViewfinder;
    });
    _speakCurrentStage();
  }

  void _approvePhoto() {
    VibrationService.gentleFeedback();
    setState(() {
      _stage = _TrainingStage.takenConfirmation;
    });
    _speakCurrentStage();
  }

  Future<void> _onPressPostpone() async {
    VibrationService.gentleFeedback();
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quando devo lembrar de novo?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (final mins in [10, 15, 30])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, mins),
                    child: Text(
                      '$mins minutos',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (minutes != null && mounted) {
      setState(() {
        _selectedMinutes = minutes;
        _stage = _TrainingStage.postponeConfirmation;
      });
      _speakCurrentStage();
    }
  }

  void _onPressHelp() {
    VibrationService.gentleFeedback();
    setState(() {
      _stage = _TrainingStage.helpConfirmation;
    });
    _speakCurrentStage();
  }

  void _advanceStep() {
    if (_freeMode) {
      setState(() {
        _stage = _TrainingStage.alarm;
      });
      _speakCurrentStage();
      return;
    }

    if (_step == 0) {
      // Já Tomei Simples -> Próximo: Foto
      setState(() {
        _step = 1;
        _stage = _TrainingStage.alarm;
      });
      _speakCurrentStage();
    } else if (_step == 1) {
      // Foto Comprovante -> Próximo: Adiar
      setState(() {
        _step = 2;
        _stage = _TrainingStage.alarm;
      });
      _speakCurrentStage();
    } else if (_step == 2) {
      // Adiar -> Próximo: Pedir Ajuda
      setState(() {
        _step = 3;
        _stage = _TrainingStage.alarm;
      });
      _speakCurrentStage();
    } else if (_step == 3) {
      // Pedir Ajuda -> Próximo: Voz Alex
      setState(() {
        _step = 4;
        _voiceConfirmed = false;
        _stage = _TrainingStage.voicePractice;
      });
      _speakCurrentStage();
    } else if (_step == 4) {
      // Voz Alex -> Próximo: Chamada de Vídeo
      setState(() {
        _step = 5;
        _videoCallAnswered = false;
        _stage = _TrainingStage.videoCallPractice;
      });
      _speakCurrentStage();
    } else {
      // Tudo concluído -> Celebração
      setState(() {
        _stage = _TrainingStage.celebration;
      });
      _confettiController.play();
      VibrationService.successPattern();
      _speakCurrentStage();
    }
  }

  void _restartTraining() {
    _confettiController.stop();
    setState(() {
      _step = 0;
      _isPhotoFlowActive = false;
      _stage = _TrainingStage.alarm;
    });
    _speakCurrentStage();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        TTSService.instance.parar(caller: this);
        VibrationService.stopVibration();
      },
      child: Scaffold(
        backgroundColor: _stage == _TrainingStage.photoViewfinder ||
                _stage == _TrainingStage.photoPreview
            ? Colors.black
            : AppColors.background,
        appBar: AppBar(
          title: const Text('Treino do Aplicativo'),
          backgroundColor: _stage == _TrainingStage.photoViewfinder ||
                  _stage == _TrainingStage.photoPreview
              ? Colors.black
              : null,
          foregroundColor: _stage == _TrainingStage.photoViewfinder ||
                  _stage == _TrainingStage.photoPreview
              ? Colors.white
              : null,
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _freeMode = !_freeMode;
                  _stage = _TrainingStage.alarm;
                });
                _speakCurrentStage();
              },
              icon: Icon(
                _freeMode ? Icons.format_list_numbered : Icons.touch_app,
                color: _stage == _TrainingStage.photoViewfinder ||
                        _stage == _TrainingStage.photoPreview
                    ? Colors.white
                    : AppColors.primary,
              ),
              label: Text(
                _freeMode ? 'Passo a passo' : 'Modo Livre',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _stage == _TrainingStage.photoViewfinder ||
                          _stage == _TrainingStage.photoPreview
                      ? Colors.white
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildSimulationSafetyBanner(),
                Expanded(
                  child: _buildStageContent(),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.amber,
                  Colors.orange,
                  Colors.purple,
                  Colors.pink,
                ],
                numberOfParticles: 40,
                gravity: 0.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Banner Superior de Segurança e Instruções ---

  Widget _buildSimulationSafetyBanner() {
    final isDone = _stage == _TrainingStage.celebration;
    final isPhoto = _stage == _TrainingStage.photoViewfinder ||
        _stage == _TrainingStage.photoPreview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.shade100
            : isPhoto
                ? Colors.grey.shade900
                : AppColors.infoContainer,
        border: Border(
          bottom: BorderSide(
            color: isDone
                ? Colors.green.shade600
                : isPhoto
                    ? Colors.grey.shade700
                    : AppColors.info,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle
                : isPhoto
                    ? Icons.camera_alt
                    : Icons.school,
            color: isDone
                ? Colors.green.shade800
                : isPhoto
                    ? Colors.amber
                    : AppColors.info,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDone
                      ? 'TREINO CONCLUÍDO COM SUCESSO!'
                      : _freeMode
                          ? 'MODO LIVRE DE TREINO'
                          : 'MODO DE TREINO: PASSO ${_step + 1} DE 4',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDone
                        ? Colors.green.shade900
                        : isPhoto
                            ? Colors.white
                            : AppColors.primary,
                  ),
                ),
                Text(
                  isDone
                      ? 'Você aprendeu todas as ações do alarme e foto.'
                      : 'Simulação segura. Nada real será enviado ou salvo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDone
                        ? Colors.green.shade900
                        : isPhoto
                            ? Colors.white70
                            : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ouvir instrução',
            icon: const Icon(Icons.volume_up, size: 24),
            color: isPhoto ? Colors.white : AppColors.primary,
            onPressed: _speakCurrentStage,
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _TrainingStage.alarm:
        return _buildActiveAlarmSimulation();
      case _TrainingStage.photoViewfinder:
        return _buildPhotoViewfinderSimulation();
      case _TrainingStage.photoPreview:
        return _buildPhotoPreviewSimulation();
      case _TrainingStage.takenConfirmation:
        return _buildTakenConfirmationSimulation();
      case _TrainingStage.postponeConfirmation:
        return _buildPostponeConfirmationSimulation();
      case _TrainingStage.helpConfirmation:
        return _buildHelpConfirmationSimulation();
      case _TrainingStage.voicePractice:
        return _buildVoicePracticeSimulation();
      case _TrainingStage.videoCallPractice:
        return _buildVideoCallPracticeSimulation();
      case _TrainingStage.celebration:
        return _buildCelebrationScreen();
    }
  }

  // --- 1. Tela de Alarme Ativo (Fiel ao ActiveReminderScreen) ---

  Widget _buildActiveAlarmSimulation() {
    final isStepPhoto = !_freeMode && _step == 1;
    final highlightStep0 = !_freeMode && _step == 0;
    final highlightStep1 = isStepPhoto;
    final highlightStep2 = !_freeMode && _step == 2;
    final highlightStep3 = !_freeMode && _step == 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      child: Column(
        children: [
          // Banner explicativo
          if (!_freeMode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _stepInstructions[_step],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            'HORA DO REMÉDIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Círculo pulsante animado
          ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.medicationsColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.medicationsColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.medicationsColor.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.medication,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Card do Lembrete
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error, width: 5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PeriodHelper.getPeriodIcon(8),
                      color: PeriodHelper.getPeriodColor(8),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LEMBRETE DA ${PeriodHelper.getPeriodLabel(8).toUpperCase()}:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: PeriodHelper.getPeriodColor(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isStepPhoto ? 'Insulina / Antibiótico' : 'Losartana 50mg',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isStepPhoto
                      ? '📸 Este remédio exige foto comprovante'
                      : '1 comprimido com meio copo de água',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isStepPhoto
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 🟢 BOTÃO 1: JÁ TOMEI (Simples ou com Foto)
          _buildActionButtonWrapper(
            highlight: highlightStep0 || highlightStep1,
            child: SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _onPressTaken,
                icon: Icon(
                  isStepPhoto ? Icons.camera_alt : Icons.check_circle,
                  size: 36,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isStepPhoto ? 'JÁ TOMEI (TIRAR FOTO)' : 'JÁ TOMEI',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),

          // Botão extra opcional no Modo Livre para testar foto
          if (_freeMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _onPressTakenWithPhoto,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text(
                  'TESTAR COM FOTO COMPROVANTE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 🟡 BOTÃO 2: LEMBRAR MAIS TARDE
          _buildActionButtonWrapper(
            highlight: highlightStep2,
            child: SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _onPressPostpone,
                icon: const Icon(Icons.access_time, size: 30),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'LEMBRAR MAIS TARDE',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onWarningContainer,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🔴 BOTÃO 3: PRECISO DE AJUDA
          _buildActionButtonWrapper(
            highlight: highlightStep3,
            child: SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _onPressHelp,
                icon: const Icon(
                  Icons.support_agent,
                  size: 30,
                  color: Colors.white,
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'PRECISO DE AJUDA',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButtonWrapper({
    required bool highlight,
    required Widget child,
  }) {
    if (!highlight) return child;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.amber.shade700, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  // --- 2. Sub-tela: Câmera / Viewfinder de Foto Comprovante ---

  Widget _buildPhotoViewfinderSimulation() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _capturePhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fundo Câmera Real ou Simulação
                if (_isCameraInitialized && _cameraController != null)
                  SizedBox.expand(
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 1080,
                          height: _cameraController!.value.previewSize?.width ?? 1920,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication, size: 90, color: Colors.white24),
                          const SizedBox(height: 12),
                          const Text(
                            'Simulador de Câmera',
                            style: TextStyle(color: Colors.white54, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Moldura "Coloque o remédio aqui" (Exatamente igual à real)
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.secondaryContainer,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.front_hand,
                        color: AppColors.secondaryContainer.withValues(alpha: 0.8),
                        size: 64,
                      ),
                      const SizedBox(height: 10),
                      Icon(Icons.circle, color: AppColors.error, size: 28),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Coloque o remédio aqui',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Flash ao bater foto
                if (_isFlashActive) Container(color: Colors.white),
              ],
            ),
          ),
        ),

        // Painel de Controle de Captura (Botão Redondo Grande)
        Container(
          height: 110,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Voltar ao alarme',
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 36),
                onPressed: () {
                  setState(() => _stage = _TrainingStage.alarm);
                  _speakCurrentStage();
                },
              ),
              GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    color: Colors.white24,
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 40),
                  ),
                ),
              ),
              const SizedBox(width: 48), // Espaçador para balancear
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. Sub-tela: Prévia da Foto com Botões Ficou Boa / Ficou Ruim ---

  Widget _buildPhotoPreviewSimulation() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_capturedPhoto != null)
                SizedBox.expand(
                  child: Image.file(
                    File(_capturedPhoto!.path),
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade900,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.green, width: 3),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medication, size: 64, color: Colors.white),
                              SizedBox(height: 8),
                              Text(
                                'Foto do Remédio',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Selo de Prévia
              Positioned(
                top: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'A foto ficou nítida?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Painel com 2 Botões Gigantes: FICOU RUIM 👎 e FICOU BOA 👍
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.black,
          child: Row(
            children: [
              // 🔴 Botão Ficou Ruim (Repetir)
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _retakePhoto,
                    icon: const Icon(Icons.thumb_down_alt_rounded, size: 30),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'FICOU RUIM 👎',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 🟢 Botão Ficou Boa (Confirmar)
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _approvePhoto,
                    icon: const Icon(Icons.thumb_up_alt_rounded, size: 30),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'FICOU BOA 👍',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. Sub-tela: Confirmação de Remédio Tomado ---

  Widget _buildTakenConfirmationSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPhotoFlowActive ? Icons.camera_alt : Icons.check_circle_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'HORA DO REMÉDIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPhotoFlowActive ? 'Remédio Comprovado!' : 'Remédio Tomado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isPhotoFlowActive
                ? 'Sua foto foi enviada com sucesso para o cuidador!'
                : 'Parabéns por cuidar da sua saúde!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No uso real, você terá 30 segundos para desfazer caso tenha apertado por engano.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 68,
            child: ElevatedButton.icon(
              onPressed: _advanceStep,
              icon: const Icon(Icons.arrow_forward, size: 30),
              label: Text(
                _freeMode
                    ? 'VOLTAR AO ALARME'
                    : _step == 0
                        ? 'PRÓXIMO PASSO: FOTO DO REMÉDIO'
                        : 'PRÓXIMO PASSO: ADIAR',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Sub-tela: Confirmação de Adiamento ---

  Widget _buildPostponeConfirmationSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 80,
                    color: AppColors.onWarningContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'HORA DO REMÉDIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lembrete Adiado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.onWarningContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vou te chamar de novo em $_selectedMinutes minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.snooze, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Excelente! Quando o tempo terminar, o aplicativo tocará novamente com o mesmo alarme.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 68,
            child: ElevatedButton.icon(
              onPressed: _advanceStep,
              icon: const Icon(Icons.arrow_forward, size: 30),
              label: Text(
                _freeMode ? 'VOLTAR AO ALARME' : 'PRÓXIMO PASSO: PEDIR AJUDA',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Sub-tela: Confirmação de Pedido de Ajuda ---

  Widget _buildHelpConfirmationSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PEDIDO DE AJUDA',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aviso Enviado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Não se preocupe, seu cuidador já foi avisado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No uso real, uma notificação imediata de emergência/dificuldade chega ao celular do cuidador.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 68,
            child: ElevatedButton.icon(
              onPressed: _advanceStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 30),
              label: Text(
                _freeMode ? 'VOLTAR AO ALARME' : 'PRÓXIMO PASSO',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-tela: Treino de Comandos de Voz com a Alex AI ---

  Widget _buildVoicePracticeSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info),
            ),
            child: Row(
              children: [
                Icon(Icons.mic_rounded, color: AppColors.info, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _voiceConfirmed
                        ? 'Excelente! Remédio confirmado por voz.'
                        : 'Toque no microfone e diga: "Já tomei meu remédio"',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Microfone Gigante Animado
          GestureDetector(
            onTap: _voiceConfirmed
                ? null
                : () async {
                    setState(() => _isVoiceListening = true);
                    await VibrationService.gentleFeedback();
                    await Future.delayed(const Duration(seconds: 2));
                    if (!mounted) return;
                    setState(() {
                      _isVoiceListening = false;
                      _voiceConfirmed = true;
                    });
                    await VibrationService.successPattern();
                    await _speak(
                      'Entendido! Confirmei seu medicamento por comando de voz.',
                    );
                  },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: _voiceConfirmed
                    ? AppColors.success
                    : _isVoiceListening
                        ? AppColors.warning
                        : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_voiceConfirmed
                            ? AppColors.success
                            : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _voiceConfirmed
                    ? Icons.check_rounded
                    : _isVoiceListening
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            _voiceConfirmed
                ? 'COMANDO RECONHECIDO!'
                : _isVoiceListening
                    ? 'OUVINDO... FALE AGORA'
                    : 'TOQUE PARA FALAR',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _voiceConfirmed
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _voiceConfirmed
                ? 'Você pode confirmar seus remédios apenas falando com a Alex!'
                : 'Experimente tocar no microfone acima para praticar a fala.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),

          if (_voiceConfirmed)
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton.icon(
                onPressed: _advanceStep,
                icon: const Icon(Icons.arrow_forward_rounded, size: 28),
                label: const Text(
                  'PRÓXIMO: CHAMADA DE VÍDEO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Sub-tela: Treino de Atender Chamada de Vídeo ---

  Widget _buildVideoCallPracticeSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.video_call_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _videoCallAnswered
                        ? 'Chamada atendida com sucesso!'
                        : 'Seu cuidador está ligando para você. Toque em ATENDER no botão verde.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Avatar da cuidadora
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 4),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 70,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dra. Ana (Cuidadora)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            _videoCallAnswered ? 'Em chamada (Simulado)' : 'Chamada de vídeo recebida...',
            style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 36),

          if (!_videoCallAnswered) ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await VibrationService.gentleFeedback();
                  setState(() => _videoCallAnswered = true);
                  await _speak('Muito bem! Você atendeu a chamada de vídeo com sucesso.');
                },
                icon: const Icon(Icons.call_rounded, size: 32),
                label: const Text(
                  'ATENDER COM VÍDEO',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await VibrationService.gentleFeedback();
                  await _speak('Você recusou a chamada. O cuidador será informado.');
                  _advanceStep();
                },
                icon: const Icon(Icons.call_end_rounded, size: 24),
                label: const Text(
                  'RECUSAR AGORA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Excelente! Você praticou como falar com seu cuidador por vídeo.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton.icon(
                onPressed: _advanceStep,
                icon: const Icon(Icons.emoji_events_rounded, size: 30),
                label: const Text(
                  'FINALIZAR TREINAMENTO',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 7. Sub-tela: Celebração & Conclusão do Treino ---

  Widget _buildCelebrationScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade600, width: 4),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 80,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PARABÉNS! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Você completou todo o treinamento!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Agora você domina todas as funções: confirmar por botão, tirar foto do remédio, adiar e pedir ajuda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.4,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),

            // Botão 1: Voltar ao Início
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home, size: 30),
                label: const Text(
                  'VOLTAR AO INÍCIO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botão 2: Treinar novamente
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _restartTraining,
                icon: const Icon(Icons.replay, size: 28),
                label: const Text(
                  'TREINAR NOVAMENTE',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
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
