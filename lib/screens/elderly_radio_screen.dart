import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/radio_service.dart';
import '../services/tts_service.dart';
import '../services/elderly_profile_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';

class ElderlyRadioScreen extends StatefulWidget {
  const ElderlyRadioScreen({super.key});

  @override
  State<ElderlyRadioScreen> createState() => _ElderlyRadioScreenState();
}

class _ElderlyRadioScreenState extends State<ElderlyRadioScreen> {
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    TTSService.instance.init();
    _loadProfilePhoto();
  }

  void _stopAllAudioAndTts() {
    TTSService.instance.parar();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final localFoto = await ElderlyProfileRepository.instance.getCachedPhotoPath();
      if (mounted) {
        setState(() {
          _fotoPath = localFoto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto na tela de rádio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighContrast = Theme.of(context).colorScheme.primary == Colors.black;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AlexFloatingHelpButton(
        textoExplicacao:
            'Olá! Esta é a sua Rádio Amiga. Aqui você pode escolher entre estações com músicas românticas, clássicos, flashback e MPB para ouvir enquanto relaxa ou faz suas atividades.',
        onTapped: _stopAllAudioAndTts,
      ),
      bottomNavigationBar: const ElderlyBottomNav(
        selected: ElderlyNavDestination.radio,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMasterPlayerCard(isHighContrast),
                    const SizedBox(height: 24),
                    Text(
                      'Escolha uma estação de música:',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isHighContrast ? Colors.black : AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStationsList(isHighContrast),
                    const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rádio Amiga 🎶',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Músicas selecionadas para o seu dia',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/elderly-profile');
            },
            child: ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterPlayerCard(bool isHighContrast) {
    return ValueListenableBuilder<bool>(
      valueListenable: RadioService.instance.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: RadioService.instance.currentStationNameNotifier,
          builder: (context, stationName, _) {
            final activeName = stationName ?? 'Toque abaixo para ouvir';

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isPlaying
                    ? (isHighContrast ? Colors.white : AppColors.primaryContainer)
                    : (isHighContrast ? Colors.white : AppColors.surfaceContainerHigh),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isHighContrast
                      ? Colors.black
                      : (isPlaying ? AppColors.primary : AppColors.outlineVariant),
                  width: isPlaying ? 4 : 2,
                ),
                boxShadow: isHighContrast
                    ? null
                    : [
                        BoxShadow(
                          color: isPlaying
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: isPlaying ? 24 : 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPlaying ? Icons.music_note : Icons.radio_outlined,
                        size: 28,
                        color: isHighContrast
                            ? Colors.black
                            : (isPlaying ? AppColors.onPrimaryContainer : AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          isPlaying ? 'Tocando agora' : 'Rádio Pausada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isHighContrast
                                ? Colors.black
                                : (isPlaying ? AppColors.onPrimaryContainer : AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activeName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isHighContrast
                          ? Colors.black
                          : (isPlaying ? AppColors.onPrimaryContainer : AppColors.onSurface),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      RadioService.instance.toggleRadio();
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isHighContrast
                            ? (isPlaying ? Colors.black : Colors.yellow)
                            : (isPlaying ? AppColors.primary : AppColors.secondaryContainer),
                        border: Border.all(
                          color: isHighContrast ? Colors.black : Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 52,
                        color: isHighContrast
                            ? (isPlaying ? Colors.white : Colors.black)
                            : (isPlaying ? Colors.white : AppColors.onSecondaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStationsList(bool isHighContrast) {
    return ValueListenableBuilder<String?>(
      valueListenable: RadioService.instance.currentStationUrlNotifier,
      builder: (context, currentUrl, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: RadioService.instance.isPlayingNotifier,
          builder: (context, isPlaying, _) {
            final stations = RadioService.instance.stations;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final station = stations[index];
                final name = station['name']!;
                final subtitle = station['subtitle']!;
                final url = station['url']!;
                final genre = station['genre']!;

                final isCurrent = currentUrl == url && isPlaying;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (isCurrent) {
                      RadioService.instance.stopRadio();
                    } else {
                      RadioService.instance.playStation(url, name, subtitle);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isHighContrast ? Colors.yellow : AppColors.secondaryContainer)
                          : (isHighContrast ? Colors.white : AppColors.surface),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isHighContrast
                            ? Colors.black
                            : (isCurrent ? AppColors.primary : AppColors.outlineVariant),
                        width: isCurrent ? 3.5 : 1.5,
                      ),
                      boxShadow: isHighContrast
                          ? null
                          : [
                              BoxShadow(
                                color: isCurrent
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: isCurrent ? 16 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isCurrent ? Icons.graphic_eq : Icons.radio,
                            size: 32,
                            color: isCurrent ? Colors.white : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isHighContrast
                                            ? Colors.black
                                            : AppColors.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      genre,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isHighContrast
                                            ? Colors.black
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isHighContrast
                                      ? Colors.black87
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
