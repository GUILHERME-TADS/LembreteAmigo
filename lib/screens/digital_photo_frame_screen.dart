import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_image_helper.dart';

class DigitalPhotoFrameScreen extends StatefulWidget {
  const DigitalPhotoFrameScreen({super.key});

  @override
  State<DigitalPhotoFrameScreen> createState() =>
      _DigitalPhotoFrameScreenState();
}

class _DigitalPhotoFrameScreenState extends State<DigitalPhotoFrameScreen> {
  Timer? _clockTimer;
  Timer? _slideTimer;
  int _currentPhotoIndex = 0;
  DateTime _currentTime = DateTime.now();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  final List<String> _affectionPhrases = [
    'Com todo o amor da sua família! ❤️',
    'Você é muito especial para nós! 🌟',
    'Tenha um dia tranquilo e cheio de paz. 🕊️',
    'Lembrando sempre com muito carinho de você! 💕',
    'Um abraço bem apertado de todos nós! 🤗',
  ];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    _slideTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        final photos = _getPhotos();
        if (photos.isNotEmpty) {
          setState(() {
            _currentPhotoIndex = (_currentPhotoIndex + 1) % photos.length;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _clockTimer?.cancel();
    _slideTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<Lembrete> _getPhotos() {
    return LembreteService.instance.lembretes
        .where(
          (l) =>
              l.medicamentoFotoPath != null &&
              l.medicamentoFotoPath!.isNotEmpty,
        )
        .toList();
  }

  Future<void> _playVoiceNote(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty) {
      TTSService.instance.falar('Foto com muito carinho da sua família!');
      return;
    }
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlayingAudio = false);
    } else {
      if (mounted) setState(() => _isPlayingAudio = true);
      try {
        if (audioPath.startsWith('http')) {
          await _audioPlayer.play(UrlSource(audioPath));
        } else {
          await _audioPlayer.play(DeviceFileSource(audioPath));
        }
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPlayingAudio = false);
        });
      } catch (e) {
        if (mounted) setState(() => _isPlayingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _getPhotos();
    final phraseIndex = _currentPhotoIndex % _affectionPhrases.length;
    final currentPhrase = _affectionPhrases[phraseIndex];

    final hourStr = DateFormat('HH:mm').format(_currentTime);
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_currentTime);

    final currentItem = photos.isNotEmpty && _currentPhotoIndex < photos.length
        ? photos[_currentPhotoIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Imagem de Fundo (Foto de Família) ou Gradiente Suave
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(seconds: 2),
                child: currentItem != null && currentItem.medicamentoFotoPath != null
                    ? Image(
                        key: ValueKey(currentItem.medicamentoFotoPath),
                        image: currentItem.medicamentoFotoPath!.startsWith('http')
                            ? NetworkImage(currentItem.medicamentoFotoPath!)
                            : AppImageHelper.resizedFileImage(
                                File(currentItem.medicamentoFotoPath!),
                                maxWidth: 1200,
                                maxHeight: 1200,
                              ),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(),
                      )
                    : _buildFallbackBackground(),
              ),
            ),

            // Sombra/Gradiente para garantir legibilidade dos textos
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Conteúdo Superior (Relógio Gigante e Data)
            Positioned(
              top: 48,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Text(
                    hourStr,
                    style: const TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 16, offset: Offset(0, 4)),
                      ],
                    ),
                  ),
                  Text(
                    dateStr.toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryContainer,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo Inferior (Mensagem Afetiva e Ações)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentPhrase,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (currentItem != null && currentItem.audioPath != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _playVoiceNote(currentItem.audioPath),
                            icon: Icon(
                              _isPlayingAudio ? Icons.pause_circle : Icons.volume_up_rounded,
                              size: 28,
                            ),
                            label: Text(
                              _isPlayingAudio ? 'Pausar Voz' : 'Ouvir Mensagem de Voz 🎙️',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryContainer,
                              foregroundColor: AppColors.onSecondaryContainer,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 24),
                        label: const Text(
                          'Sair do Porta-Retratos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.voiceFeedbackBlue, AppColors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.family_restroom_rounded,
          size: 120,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
