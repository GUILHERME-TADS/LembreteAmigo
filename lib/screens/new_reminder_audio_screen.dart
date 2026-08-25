import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../services/tts_service.dart';
import '../widgets/responsive_layout.dart';

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
    await TTSService.instance.parar();
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
      }

      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permissao de microfone negada. Autorize o acesso para gravar.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/familiar_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordedFilePath = null;
      });
    } catch (e) {
      debugPrint('Erro ao iniciar gravacao: $e');
      if (!mounted) return;
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel iniciar a gravacao: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!await _audioRecorder.isRecording()) {
        setState(() => _isRecording = false);
        return;
      }

      final path = await _audioRecorder.stop();
      if (path == null) {
        _showRecordingError();
        return;
      }

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        _showRecordingError();
        return;
      }

      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      debugPrint('Erro ao parar gravacao: $e');
      if (!mounted) return;
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel salvar a gravacao: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRecordingError() {
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedFilePath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A gravacao nao foi salva. Tente novamente.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _togglePlayback() async {
    final path = _recordedFilePath;
    if (path == null) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      _showRecordingError();
      return;
    }

    setState(() => _isPlaying = true);
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    try {
      await _audioPlayer.play(DeviceFileSource(path), volume: 1.0);
    } catch (e) {
      debugPrint('Erro ao tocar gravacao: $e');
      if (mounted) setState(() => _isPlaying = false);
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
    final compact = context.isCompactHeight || context.isLandscape;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ResponsiveScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                maxContentWidth: 720,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isRecording && _recordedFilePath == null) ...[
                          GestureDetector(
                            onTap: _startRecording,
                            child: Container(
                              width: compact ? 140 : 170,
                              height: compact ? 140 : 170,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 6,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.mic,
                                size: 72,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Toque para começar a gravar',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Fale com tom carinhoso e calmo.\nSua voz traz segurança para o idoso.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ] else if (_isRecording) ...[
                          GestureDetector(
                            onTap: _stopRecording,
                            child: Container(
                              width: compact ? 140 : 170,
                              height: compact ? 140 : 170,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error,
                                    blurRadius: 24,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.stop,
                                size: 72,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Gravando sua voz...',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toque no botão vermelho quando terminar.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
                          // CARD DE ÁUDIO GRAVADO
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryContainer,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _togglePlayback,
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          color: _isPlaying
                                              ? AppColors.error
                                              : AppColors.primaryContainer,
                                          shape: BoxShape.circle,
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.stop
                                              : Icons.play_arrow_rounded,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 28),
                                    GestureDetector(
                                      onTap: _startRecording,
                                      child: Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.outlineVariant,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.refresh,
                                          size: 36,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _isPlaying
                                      ? 'Tocando voz gravada...'
                                      : 'Voz gravada com sucesso!',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Toque no play azul para escutar antes de salvar.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_recordedFilePath != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _salvarRetornar,
                          icon: const Icon(Icons.check_circle, size: 32),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SALVAR E VINCULAR',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            minimumSize: const Size.fromHeight(72),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          Expanded(
            child: Text(
              'Gravar Voz do Familiar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
