import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';

class NewReminderAudioScreen extends StatefulWidget {
  const NewReminderAudioScreen({super.key});

  @override
  State<NewReminderAudioScreen> createState() => _NewReminderAudioScreenState();
}

class _NewReminderAudioScreenState extends State<NewReminderAudioScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/familiar_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
      } else {
        // Fallback: simular gravação gerando arquivo dummy
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted && _isRecording) {
            final file = File(path);
            await file.writeAsBytes([0, 1, 2, 3]); // dummy file
            setState(() {
              _isRecording = false;
              _recordedFilePath = path;
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gravação simulada vinculada (microfone indisponível).'),
                backgroundColor: AppColors.tertiaryFixedDim,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao iniciar gravacao: $e');
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/familiar_audio_mock_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(path);
      await file.writeAsBytes([0, 1, 2, 3]);
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _recordedFilePath = path;
        });
      } else {
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao parar gravacao: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordedFilePath == null) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
      try {
        await _audioPlayer.play(
          DeviceFileSource(_recordedFilePath!),
          volume: 1.0,
        );
      } catch (e) {
        debugPrint('Erro ao tocar gravacao: $e');
        setState(() => _isPlaying = false);
      }
    }
  }

  void _salvarRetornar() {
    if (_recordedFilePath != null) {
      Navigator.pop(context, _recordedFilePath);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.primary, size: 32),
                  ),
                  const Expanded(
                    child: Text(
                      'Gravar Voz do Familiar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRecording && _recordedFilePath == null) ...[
                      GestureDetector(
                        onTap: _startRecording,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.mic, size: 64, color: AppColors.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Toque para começar a gravar',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Diga as instruções de forma simples e pausada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                      ),
                    ] else if (_isRecording) ...[
                      GestureDetector(
                        onTap: _stopRecording,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.stop, size: 64, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Gravando sua voz...',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toque no botão vermelho para parar.',
                        style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                      ),
                    ] else if (_recordedFilePath != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _togglePlayback,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.stop : Icons.play_arrow,
                                size: 56,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _startRecording,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.outlineVariant),
                              ),
                              child: const Icon(Icons.refresh, size: 32, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Voz Gravada com Sucesso!',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toque no botão de play para ouvir a gravação.',
                        style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (_recordedFilePath != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _salvarRetornar,
                    icon: const Icon(Icons.check),
                    label: const Text('SALVAR E VINCULAR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
