import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../services/health_service.dart';
import '../widgets/volume_warning_banner.dart';
import '../widgets/me_explica_button.dart';

class HeartRateMeasureScreen extends StatefulWidget {
  const HeartRateMeasureScreen({super.key});

  @override
  State<HeartRateMeasureScreen> createState() => _HeartRateMeasureScreenState();
}

class _HeartRateMeasureScreenState extends State<HeartRateMeasureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFingerDetected = false;
  bool _isFinished = false;

  final List<SensorValue> _measurements = [];
  int _bpm = 0;
  double _progress = 0.0;
  DateTime? _startTime;
  Timer? _timer;

  // Variáveis para a animação do coração pulsante
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPulseAnimation();
    _initCamera();

    // Instrução inicial de voz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Por favor, coloque o seu dedo indicador na câmera de trás do celular e cubra também o flash.',
        caller: this,
      );
    });
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updatePulseDuration(int bpm) {
    if (bpm > 40 && bpm < 180) {
      final msPerBeat = (60000 / bpm).toInt();
      // O ciclo repeat + reverse dobra a duração aparente, então dividimos por 2
      _pulseController.duration = Duration(milliseconds: msPerBeat ~/ 2);
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('Nenhuma câmera encontrada no dispositivo.');
        return;
      }

      // Procurar câmera traseira
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        rearCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // Ligar o flash em modo contínuo (torch)
      await _controller!.setFlashMode(FlashMode.torch);

      // Iniciar captura de quadros
      _controller!.startImageStream((CameraImage image) {
        if (_isProcessing || _isFinished || !mounted) return;
        _isProcessing = true;
        _scanImage(image);
      });
    } catch (e) {
      _showError('Erro ao inicializar a câmera: $e');
    }
  }

  void _scanImage(CameraImage image) {
    try {
      // Y plane (luminosidade) em YUV420 é sempre a primeira plane
      final bytes = image.planes[0].bytes;

      // Calcular a luminosidade média fazendo sub-amostragem para desempenho (pega 1 de cada 10 bytes)
      int sum = 0;
      int step = 10;
      int count = 0;
      for (int i = 0; i < bytes.length; i += step) {
        sum += bytes[i];
        count++;
      }

      final double avgLuminosity = count > 0 ? sum / count : 0.0;

      // Sob a luz do flash direta contra a pele do dedo, a luminosidade Y é muito forte.
      // Sem o dedo, a luz se dissipa e o valor Y cai drasticamente (ou oscila).
      // Heurística de dedo posicionado: média de brilho maior que 85.
      final bool isFingerOnSensor = avgLuminosity > 85;

      if (!isFingerOnSensor) {
        // Se o dedo foi removido ou não detectado
        if (_isFingerDetected) {
          setState(() {
            _isFingerDetected = false;
            _measurements.clear();
            _bpm = 0;
            _progress = 0.0;
            _startTime = null;
            _pulseController.duration = const Duration(milliseconds: 1000);
          });
          TTSService.instance.falar(
            'Dedo removido. Por favor, coloque o seu dedo na câmera de trás cobrindo o flash.',
            caller: this,
          );
        }
        _isProcessing = false;
        return;
      }

      // Dedo detectado!
      if (!_isFingerDetected) {
        setState(() {
          _isFingerDetected = true;
          _startTime = DateTime.now();
        });
        TTSService.instance.falar(
          'Dedo detectado. Fique parado e em silêncio.',
          caller: this,
        );
      }

      final now = DateTime.now();
      setState(() {
        _measurements.add(SensorValue(time: now, value: avgLuminosity));
        if (_measurements.length > 50) {
          _measurements.removeAt(0);
        }
      });

      _calculateBPM();

      // Aguarda 50ms antes de processar o próximo frame
      Future.delayed(const Duration(milliseconds: 50)).then((_) {
        _isProcessing = false;
      });
    } catch (e) {
      _isProcessing = false;
    }
  }

  void _calculateBPM() {
    if (_startTime == null || _measurements.length < 20) return;

    final elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;

    // Atualiza progresso da medição (queremos 15 segundos estáveis)
    setState(() {
      _progress = (elapsedSeconds / 15.0).clamp(0.0, 1.0);
    });

    if (_progress >= 1.0) {
      if (HealthService.isValidBpm(_bpm)) {
        _finishMeasurement();
      } else {
        _restartMeasurementDueToUnstableSignal();
      }
      return;
    }

    // Algoritmo de cálculo de batimentos por PPG
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0.0;

    for (var m in _measurements) {
      final val = m.value.toDouble();
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
      sum += val;
    }

    final double avgVal = sum / _measurements.length;
    final double range = maxVal - minVal;

    // Se o sinal oscilar muito pouco, é estático ou ruído irrelevante
    if (range < 1.5) return;

    final double threshold = (maxVal + avgVal) / 2.0;

    List<DateTime> peaks = [];
    bool isBelow = true;

    for (int i = 0; i < _measurements.length; i++) {
      final val = _measurements[i].value.toDouble();
      if (isBelow) {
        if (val > threshold) {
          peaks.add(_measurements[i].time);
          isBelow = false;
        }
      } else {
        if (val < threshold) {
          isBelow = true;
        }
      }
    }

    if (peaks.length >= 2) {
      List<double> bpms = [];
      for (int i = 1; i < peaks.length; i++) {
        final diffMs = peaks[i].difference(peaks[i - 1]).inMilliseconds;
        if (diffMs > 350 && diffMs < 1500) {
          // Limita frequências coerentes (40-170 BPM)
          bpms.add(60000.0 / diffMs);
        }
      }

      if (bpms.isNotEmpty) {
        final double avgBpmCalculated =
            bpms.reduce((a, b) => a + b) / bpms.length;

        setState(() {
          // Suavização exponencial rápida (EMA)
          if (_bpm == 0) {
            _bpm = avgBpmCalculated.toInt();
          } else {
            _bpm = ((0.8 * _bpm) + (0.2 * avgBpmCalculated)).toInt();
          }
          _updatePulseDuration(_bpm);
        });
      }
    }
  }

  void _restartMeasurementDueToUnstableSignal() {
    if (!mounted) return;
    setState(() {
      _measurements.clear();
      _bpm = 0;
      _progress = 0.0;
      _startTime = DateTime.now();
      _pulseController.duration = const Duration(milliseconds: 1000);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nao foi possivel medir ainda. Cubra bem a camera e o flash e fique parado.',
        ),
      ),
    );
    TTSService.instance.falar(
      'Nao consegui medir ainda. Cubra bem a camera e o flash e fique parado.',
      caller: this,
    );
  }

  void _finishMeasurement() async {
    if (_isFinished) return;
    if (!HealthService.isValidBpm(_bpm)) {
      _restartMeasurementDueToUnstableSignal();
      return;
    }

    setState(() {
      _isFinished = true;
      _progress = 1.0;
    });

    try {
      if (_controller != null) {
        await _controller!.stopImageStream();
        await _controller!.setFlashMode(FlashMode.off);
      }
    } catch (_) {}

    // Salvar último resultado localmente e na nuvem
    await HealthService.instance.enviarMetricas(_bpm);

    // Anunciar por áudio
    TTSService.instance.falar(
      'Medição concluída com sucesso! Sua frequência cardíaca é de $_bpm batimentos por minuto.',
      caller: this,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Erro de Câmera',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    TTSService.instance.parar(caller: this);

    // Parar stream e flash se o usuário sair antes de concluir
    if (_controller != null) {
      _controller!.setFlashMode(FlashMode.off).then((_) {
        _controller!.dispose();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calcular limites para desenhar no CustomPainter
    double minVal = 0.0;
    double maxVal = 255.0;
    double threshold = 128.0;

    if (_measurements.isNotEmpty) {
      minVal = _measurements
          .map((m) => m.value)
          .reduce((a, b) => a < b ? a : b)
          .toDouble();
      maxVal = _measurements
          .map((m) => m.value)
          .reduce((a, b) => a > b ? a : b)
          .toDouble();
      final double sum = _measurements
          .map((m) => m.value)
          .reduce((a, b) => a + b)
          .toDouble();
      final double avg = sum / _measurements.length;
      threshold = (maxVal + avg) / 2.0;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'Medir Batimentos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Spacer simétrico
                ],
              ),
            ),
            const SizedBox(height: 12),
            const MeExplicaButton(
              textoExplicacao:
                  'Olá! Esta é a tela para ver como está o seu coração. Coloque a ponta do seu dedo indicador em cima da câmera traseira do celular, cobrindo ela inteira, e segure firme. A medição vai começar sozinha.',
            ),
            const SizedBox(height: 12),

            // Corpo Principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Instrução visual do topo
                    Card(
                      elevation: 0,
                      color: _isFingerDetected
                          ? AppColors.tertiaryFixed.withValues(alpha: 0.3)
                          : AppColors.secondaryFixed.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _isFingerDetected
                              ? AppColors.onTertiaryFixedVariant
                              : AppColors.onSecondaryFixedVariant,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Icon(
                              _isFingerDetected
                                  ? Icons.check_circle
                                  : Icons.info,
                              size: 40,
                              color: _isFingerDetected
                                  ? AppColors.onTertiaryFixedVariant
                                  : AppColors.onSecondaryFixedVariant,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _isFingerDetected
                                    ? 'Dedo detectado! Fique firme e silencioso.'
                                    : 'Coloque a ponta do indicador cobrindo a câmera e o flash.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _isFingerDetected
                                      ? AppColors.onTertiaryFixedVariant
                                      : AppColors.onSecondaryFixedVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Área central do coração pulsante
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Círculo de Progresso Externo
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _isCameraInitialized ? _progress : null,
                            strokeWidth: 10,
                            backgroundColor: AppColors.outlineVariant
                                .withValues(alpha: 0.5),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.redAccent,
                            ),
                          ),
                        ),
                        // Coração Animado
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _bpm > 0 ? '$_bpm' : '--',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'BPM',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Gráfico do sinal PPG
                    if (_isFingerDetected && _measurements.length >= 2)
                      Container(
                        height: 100,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: CustomPaint(
                          painter: PPGPainter(
                            _measurements,
                            threshold,
                            minVal,
                            maxVal,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.outlineVariant,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Text(
                          'Aguardando leitura de sinal...',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Barra de progresso inferior ou resultado
                    if (_isFinished)
                      Text(
                        'Medição concluída: $_bpm batimentos/minuto',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(
                        'Progresso da Medição: ${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),

                    // Botão voltar final
                    if (_isFinished)
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text(
                            'Voltar para Ajuda',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SensorValue {
  final DateTime time;
  final num value;

  SensorValue({required this.time, required this.value});
}

class PPGPainter extends CustomPainter {
  final List<SensorValue> points;
  final double threshold;
  final double minVal;
  final double maxVal;

  PPGPainter(this.points, this.threshold, this.minVal, this.maxVal);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / 50;

    double range = maxVal - minVal;
    if (range == 0) range = 1.0;

    for (int i = 0; i < points.length; i++) {
      final double val = points[i].value.toDouble();
      // Mapeia o valor Y invertendo devido ao plano de coordenadas do canvas
      double y = size.height - ((val - minVal) / range) * size.height;
      y = y.clamp(5.0, size.height - 5.0); // Margem de segurança de 5px
      final double x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Linha média de threshold dinâmica
    if (threshold > 0) {
      final threshPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.2)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      double threshY =
          size.height - ((threshold - minVal) / range) * size.height;
      threshY = threshY.clamp(0.0, size.height);
      canvas.drawLine(
        Offset(0, threshY),
        Offset(size.width, threshY),
        threshPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PPGPainter oldDelegate) {
    return true;
  }
}
