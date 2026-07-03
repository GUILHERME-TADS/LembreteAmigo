import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/lembrete_service.dart';
import '../models/lembrete.dart';
import '../widgets/index.dart';

class TakePhotoConfirmationScreen extends StatefulWidget {
  const TakePhotoConfirmationScreen({super.key});

  @override
  State<TakePhotoConfirmationScreen> createState() => _TakePhotoConfirmationScreenState();
}

class _TakePhotoConfirmationScreenState extends State<TakePhotoConfirmationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCaptured = false;
  bool _isFlashActive = false;
  XFile? _capturedFile;
  final FocusNode _focusNode = FocusNode();
  bool _isProfilePhoto = false;
  String? _lembreteId;
  bool _hasSpokenExplanation = false;
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSpokenExplanation) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _isProfilePhoto = args == 'profile_photo';
      _lembreteId = args is String ? args : null;
      if (_isProfilePhoto) {
        TTSService.instance.falar(
          'Olhe para a câmera e aperte na tela para tirar a foto de perfil.',
          caller: this,
        );
      } else {
        TTSService.instance.falar(
          'Coloque o remédio na frente do celular e aperte na tela para tirar a foto.',
          caller: this,
        );
      }
      _hasSpokenExplanation = true;
    }
  }

  Future<void> _initCamera() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('Nenhuma câmera encontrada.');
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );

      _lensDirection = selectedCamera.lensDirection;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Erro ao inicializar câmera: $e');
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _lensDirection = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await _initCamera();
  }

  Future<void> _capturePhoto(String? lembreteId) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      setState(() {
        _isFlashActive = true;
      });

      final file = await _cameraController!.takePicture();

      setState(() {
        _isCaptured = true;
        _capturedFile = file;
      });

      TTSService.instance.falar('Foto tirada.', caller: this);
      
      // Analyze color in the background
      _analyzePhotoColor(file, lembreteId);
    } catch (e) {
      debugPrint('Erro ao tirar foto: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _isFlashActive = false;
          });
        }
      });
    }
  }

  Future<void> _analyzePhotoColor(XFile file, String? lembreteId) async {
    if (_isProfilePhoto || lembreteId == 'profile_photo') return;
    try {
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      
      final int startX = (decoded.width / 2 - 40).toInt().clamp(0, decoded.width);
      final int startY = (decoded.height / 2 - 40).toInt().clamp(0, decoded.height);
      
      int rSum = 0, gSum = 0, bSum = 0, count = 0;
      for (int y = startY; y < startY + 80 && y < decoded.height; y++) {
        for (int x = startX; x < startX + 80 && x < decoded.width; x++) {
          final pixel = decoded.getPixel(x, y);
          rSum += pixel.r.toInt();
          gSum += pixel.g.toInt();
          bSum += pixel.b.toInt();
          count++;
        }
      }
      
      if (count > 0) {
        final r = rSum ~/ count;
        final g = gSum ~/ count;
        final b = bSum ~/ count;
        
        final detected = _detectColorName(r, g, b);
        debugPrint('Cor detectada no centro: $detected (RGB: $r, $g, $b)');
        
        Lembrete? target;
        if (lembreteId != null) {
          final idx = LembreteService.instance.lembretes.indexWhere((l) => l.id == lembreteId);
          if (idx != -1) target = LembreteService.instance.lembretes[idx];
        } else {
          final meds = LembreteService.instance.lembretes
              .where((l) => l.categoria == 'medicacao' && !l.concluido)
              .toList();
          if (meds.isNotEmpty) target = meds.first;
        }
        
        if (target != null && target.medicamentoCor != null) {
          final targetColor = target.medicamentoCor!.toLowerCase();
          if (targetColor.isNotEmpty && !targetColor.contains(detected) && !detected.contains(targetColor)) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                TTSService.instance.falar(
                  'Atenção! Esta pílula parece ser $detected. O remédio correto agendado deveria ser $targetColor. Por favor, verifique se pegou a pílula certa.',
                  caller: this,
                );
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao analisar cor: $e');
    }
  }

  String _detectColorName(int r, int g, int b) {
    final double maxVal = max(r, max(g, b)).toDouble();
    final double minVal = min(r, min(g, b)).toDouble();
    final double delta = maxVal - minVal;

    double h = 0;
    if (delta > 0) {
      if (maxVal == r) {
        h = (60 * ((g - b) / delta) + 360) % 360;
      } else if (maxVal == g) {
        h = (60 * ((b - r) / delta) + 120) % 360;
      } else {
        h = (60 * ((r - g) / delta) + 240) % 360;
      }
    }

    final double s = maxVal == 0 ? 0 : delta / maxVal;
    final double v = maxVal / 255.0;

    if (v < 0.25) return 'preto';
    if (s < 0.15 && v > 0.75) return 'branco';
    if (s < 0.15) return 'cinza';

    if (h < 15 || h > 345) return 'vermelho';
    if (h >= 15 && h < 45) return 'laranja';
    if (h >= 45 && h < 72) return 'amarelo';
    if (h >= 72 && h < 165) return 'verde';
    if (h >= 165 && h < 255) return 'azul';
    if (h >= 255 && h < 315) return 'roxo';
    return 'rosa';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? lembreteId = args is String ? args : null;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (!_isCaptured && event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
              event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
            _capturePhoto(lembreteId);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(context),
                  const VolumeWarningBanner(),
                  const MeExplicaButton(
                    textoExplicacao: 'Olá! Esta é a tela para tirar foto. Mostre a tarefa que você fez para a câmera e aperte o botão redondo no meio para tirar a foto. Se a foto ficar boa, aperte o botão de Confirmar.',
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: !_isCaptured ? () => _capturePhoto(lembreteId) : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!_isCaptured)
                            _buildCameraViewfinder()
                          else
                            _buildPhotoPreview(),

                          if (!_isCaptured)
                            _buildSilhouetteOverlay(lembreteId),

                          if (_isFlashActive)
                            Container(
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ),
                  _buildControlPanel(context, lembreteId),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 36),
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
          ),
          const Expanded(
            child: Text(
              'Confirmar com Foto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondaryContainer),
      );
    }
    return SizedBox.expand(
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
    );
  }

  Widget _buildSilhouetteOverlay(String? lembreteId) {
    final isProfilePhoto = _isProfilePhoto || lembreteId == 'profile_photo';
    
    if (isProfilePhoto) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 260,
            height: 320,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.secondaryContainer,
                width: 4,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(130),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.secondaryContainer.withValues(alpha: 0.8),
                  size: 100,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Posicione seu rosto aqui',
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
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.secondaryContainer,
              width: 4,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.front_hand,
                color: AppColors.secondaryContainer.withValues(alpha: 0.8),
                size: 72,
              ),
              const SizedBox(height: 12),
              const Icon(
                Icons.circle,
                color: Colors.redAccent,
                size: 32,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (_capturedFile == null) return const SizedBox();
    return SizedBox.expand(
      child: Image.file(
        File(_capturedFile!.path),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, String? lembreteId) {
    if (!_isCaptured) {
      return Container(
        height: 140,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            InkWell(
              onTap: () => _capturePhoto(lembreteId),
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white, width: 6),
                ),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryContainer,
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.onSecondaryContainer, size: 36),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.sync, color: Colors.white, size: 32),
                onPressed: _toggleCamera,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCaptured = false;
                      _capturedFile = null;
                    });
                    TTSService.instance.falar('Câmera aberta novamente.', caller: this);
                  },
                  icon: const Icon(Icons.refresh, size: 32),
                  label: const Text(
                    'TENTAR DE NOVO',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    TTSService.instance.parar(caller: this);
                    if (_isProfilePhoto || lembreteId == 'profile_photo') {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('idoso_foto_path', _capturedFile!.path);
                      final idosoId = prefs.getString('paired_idoso_id') ?? 'joao';
                      try {
                        await FirebaseFirestore.instance
                            .collection('idoso_perfil')
                            .doc(idosoId)
                            .set({'fotoPath': _capturedFile!.path}, SetOptions(merge: true));
                        await FirebaseFirestore.instance
                            .collection('idosos')
                            .doc(idosoId)
                            .set({'fotoPath': _capturedFile!.path}, SetOptions(merge: true));
                      } catch (e) {
                        debugPrint('Erro ao salvar foto de perfil: $e');
                      }
                      SystemSound.play(SystemSoundType.click);
                      HapticFeedback.vibrate();
                      navigator.pop(_capturedFile!.path);
                      return;
                    } else if (lembreteId != null) {
                      await LembreteService.instance.concluirComFoto(lembreteId);
                    } else {
                      final medicacoes = LembreteService.instance.lembretes
                          .where((l) => l.categoria == 'medicacao' && !l.concluido)
                          .toList();
                      if (medicacoes.isNotEmpty) {
                        await LembreteService.instance.concluirComFoto(medicacoes.first.id);
                      }
                    }
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.vibrate();
                    navigator.pushNamedAndRemoveUntil(
                      '/medication-confirmation',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.send, size: 32),
                  label: const Text(
                    'CONFIRMAR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiaryFixedDim,
                    foregroundColor: AppColors.onTertiaryFixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _focusNode.dispose();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }
}
