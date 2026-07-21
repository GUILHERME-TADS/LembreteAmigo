import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class RadioService {
  RadioService._();
  static final RadioService instance = RadioService._();

  final AudioPlayer _player = AudioPlayer();
  
  // Notifica a UI se a rádio está tocando
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  // Notifica o nome da estação (se aplicável)
  final ValueNotifier<String?> currentStationNameNotifier = ValueNotifier<String?>(null);

  // Notifica a URL da estação tocando (para destaque na UI)
  final ValueNotifier<String?> currentStationUrlNotifier = ValueNotifier<String?>(null);

  // Lista de rádios premium 100% musicais com links HTTPS diretos e estáveis
  final List<Map<String, String>> stations = [
    {
      'name': 'Rádio Antena 1',
      'subtitle': 'Clássicos, românticas e flashback',
      'url': 'https://antenaone.crossradio.com.br/stream/1',
      'genre': 'Flashback',
    },
    {
      'name': 'Nova Brasil FM',
      'subtitle': 'Música Popular Brasileira de qualidade',
      'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/NOVABRASIL_SPAAC.aac',
      'genre': 'MPB',
    },
    {
      'name': 'Alpha FM',
      'subtitle': 'Pop leve, jazz e sucessos selecionados',
      'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ALPHAFM_ADP.aac',
      'genre': 'Pop & Jazz',
    },
    {
      'name': 'Saudade FM',
      'subtitle': 'Boleros, flashback e grandes clássicos de ouro',
      'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/SAUDADE_FMAAC.aac',
      'genre': 'Clássicos',
    },
    {
      'name': 'Sertaneja 106.7 FM',
      'subtitle': 'Sucessos sertanejos românticos e modão caipira',
      'url': 'https://sc4s.cdn.upx.com:8067/stream',
      'genre': 'Sertanejo',
    },
    {
      'name': 'Bossa Jazz Brasil',
      'subtitle': 'Bossa Nova e música relaxante para o dia a dia',
      'url': 'https://centova5.transmissaodigital.com:20104/live',
      'genre': 'Bossa Nova',
    },
    {
      'name': 'JB FM',
      'subtitle': 'MPB e sucessos inesquecíveis',
      'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JBFMAAC1.aac',
      'genre': 'Sucessos',
    },
  ];

  bool _isInit = false;

  void _initIfNeeded() {
    if (_isInit) return;
    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
    });
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        debugPrint('Erro no stream de áudio: $e');
        isPlayingNotifier.value = false;
        currentStationNameNotifier.value = 'Erro ao conectar';
      },
    );
    _isInit = true;
  }

  Future<void> toggleRadio() async {
    _initIfNeeded();
    if (isPlayingNotifier.value) {
      await stopRadio();
    } else {
      if (currentStationUrlNotifier.value != null) {
        final url = currentStationUrlNotifier.value!;
        final matching = stations.firstWhere((s) => s['url'] == url, orElse: () => stations.first);
        await playStation(matching['url']!, matching['name']!, matching['subtitle']);
      } else {
        await playRadio();
      }
    }
  }

  Future<void> stopRadio() async {
    _initIfNeeded();
    await _player.stop();
  }

  bool _isChangingStation = false;

  Future<void> playStation(String url, String name, [String? subtitle]) async {
    _initIfNeeded();
    if (_isChangingStation) {
      await _player.stop();
    }
    _isChangingStation = true;
    try {
      currentStationNameNotifier.value = name;
      currentStationUrlNotifier.value = url;

      await _player.stop();
      final source = AudioSource.uri(Uri.parse(url));
      await _player.setAudioSource(source);
      _player.play();
    } catch (e) {
      if (e.toString().contains('abort') || e.toString().contains('interrupted')) {
        return; // Usuário pulou a estação muito rápido, ignorar o erro
      }
      debugPrint('Erro ao tentar tocar a estação $name ($url): $e');
      currentStationNameNotifier.value = 'Erro ao conectar';
      currentStationUrlNotifier.value = null;
    } finally {
      _isChangingStation = false;
    }
  }

  Future<void> nextStation() async {
    _initIfNeeded();
    if (stations.isEmpty) return;
    final currentUrl = currentStationUrlNotifier.value;
    int currentIndex = stations.indexWhere((s) => s['url'] == currentUrl);
    int nextIndex = (currentIndex + 1) % stations.length;
    final next = stations[nextIndex];
    await playStation(next['url']!, next['name']!, next['subtitle']);
  }

  Future<void> previousStation() async {
    _initIfNeeded();
    if (stations.isEmpty) return;
    final currentUrl = currentStationUrlNotifier.value;
    int currentIndex = stations.indexWhere((s) => s['url'] == currentUrl);
    if (currentIndex == -1) currentIndex = 0;
    int prevIndex = (currentIndex - 1 + stations.length) % stations.length;
    final prev = stations[prevIndex];
    await playStation(prev['url']!, prev['name']!, prev['subtitle']);
  }

  Future<void> playRadio() async {
    _initIfNeeded();
    currentStationNameNotifier.value = 'Procurando estação...';

    // Escolhe uma rádio aleatória e tenta o fallback caso alguma falhe na conexão
    final startIndex = DateTime.now().millisecondsSinceEpoch % stations.length;
    bool connected = false;

    for (int i = 0; i < stations.length; i++) {
      final station = stations[(startIndex + i) % stations.length];
      final streamUrl = station['url']!;
      final stationName = station['name']!;

      try {
        currentStationNameNotifier.value = stationName;
        currentStationUrlNotifier.value = streamUrl;

        final source = AudioSource.uri(Uri.parse(streamUrl));
        await _player.setAudioSource(source);
        _player.play();
        connected = true;
        break;
      } catch (e) {
        debugPrint('Erro ao tentar tocar a estação $stationName ($streamUrl): $e');
        // Tenta a próxima estação da lista caso falhe
      }
    }

    if (!connected) {
      currentStationNameNotifier.value = 'Erro ao conectar';
      currentStationUrlNotifier.value = null;
      debugPrint('Erro: Não foi possível conectar a nenhuma estação de rádio.');
    }
  }
}

