import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../utils/period_helper.dart';
import '../widgets/index.dart';

class ReminderDetailScreen extends StatefulWidget {
  const ReminderDetailScreen({super.key});

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  Lembrete? _lembrete;
  bool _hasSpoken = false;
  bool _isSpeakingAudio = false;
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
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
      debugPrint('Erro ao carregar foto no reminder detail: $e');
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSpoken) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Lembrete) {
        _lembrete = args;
      }
      _speak();
    }
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  _ReminderCategoryConfig get _config {
    final cat = _lembrete?.categoria ?? '';
    if (cat == 'medicacao') {
      return _ReminderCategoryConfig(
        icon: Icons.medication_rounded,
        color: AppColors.medicationsColor,
        topBarTitle: 'Hora do Remédio',
        defaultTitle: 'HORA DO REMÉDIO',
        defaultSubtitle: _lembrete != null
            ? 'Remédio marcado para às ${_lembrete!.horarioFormatado}.'
            : 'Está na hora do seu remédio!',
        detailedExplanation:
            'Olá, esta é a tela do seu remédio. Aqui você pode ver a foto, o horário e como tomar. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) {
          final inst = (l.medicamentoInstrucoes != null && l.medicamentoInstrucoes!.isNotEmpty)
              ? ' Como tomar: ${l.medicamentoInstrucoes}.'
              : '';
          return 'Remédio: ${l.titulo} às $timeStr.$inst';
        },
        defaultSpokenText: () => 'Hora de tomar seu remédio.',
      );
    } else if (cat == 'refeicoes') {
      return _ReminderCategoryConfig(
        icon: Icons.restaurant_rounded,
        color: AppColors.mealsColor,
        topBarTitle: 'Hora de Comer',
        defaultTitle: 'HORA DE COMER',
        defaultSubtitle: _lembrete != null
            ? 'Comida marcada para às ${_lembrete!.horarioFormatado}. Bom apetite!'
            : 'Sua comida está pronta. Bom apetite!',
        detailedExplanation:
            'Olá, esta é a tela da sua comida. Aqui você pode ver o horário e ouvir de novo o que fazer.',
        spokenText: (l, timeStr) =>
            'Comer: ${l.titulo} às $timeStr.',
        defaultSpokenText: () => 'Hora de comer.',
      );
    } else if (cat == 'exercicio') {
      return _ReminderCategoryConfig(
        icon: Icons.directions_walk_rounded,
        color: AppColors.tertiaryContainer,
        topBarTitle: 'Vamos nos Mexer',
        defaultTitle: 'HORA DO EXERCÍCIO',
        defaultSubtitle: _lembrete != null
            ? 'Exercício marcado para às ${_lembrete!.horarioFormatado}. Vamos lá!'
            : 'Vamos nos movimentar!',
        detailedExplanation:
            'Olá, esta é a tela do seu exercício. Aqui você pode ver o horário e ouvir de novo o que fazer.',
        spokenText: (l, timeStr) =>
            'Exercício: ${l.titulo} às $timeStr.',
        defaultSpokenText: () => 'Hora de fazer exercício.',
      );
    } else if (cat == 'hidratacao') {
      return _ReminderCategoryConfig(
        icon: Icons.water_drop_rounded,
        color: AppColors.voiceFeedbackBlue,
        topBarTitle: 'Hora da Água',
        defaultTitle: 'HORA DA ÁGUA',
        defaultSubtitle: _lembrete != null
            ? 'Água marcada para às ${_lembrete!.horarioFormatado}.'
            : 'Hora de beber um copo d\'água!',
        detailedExplanation:
            'Olá! Beber água faz bem. Aqui você pode ver o horário e ouvir de novo o que fazer.',
        spokenText: (l, timeStr) =>
            'Beber água: ${l.titulo} às $timeStr.',
        defaultSpokenText: () => 'Hora de beber água.',
      );
    } else {
      return _ReminderCategoryConfig(
        icon: Icons.notifications_active_rounded,
        color: AppColors.primary,
        topBarTitle: 'Meu Lembrete',
        defaultTitle: 'LEMBRETE',
        defaultSubtitle: _lembrete != null
            ? 'Lembrete marcado para às ${_lembrete!.horarioFormatado}.'
            : 'Atenção ao seu lembrete!',
        detailedExplanation:
            'Olá, esta é a tela do seu lembrete. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) =>
            'Lembrete: ${l.titulo} às $timeStr.',
        defaultSpokenText: () => 'Hora do lembrete.',
      );
    }
  }

  void _speak() async {
    _hasSpoken = true;
    setState(() => _isSpeakingAudio = true);
    final cfg = _config;
    final text = _lembrete != null
        ? cfg.spokenText(
            _lembrete!,
            PeriodHelper.getSpokenTime(
              _lembrete!.horarioHour,
              _lembrete!.horarioMinute,
            ),
          )
        : cfg.defaultSpokenText();

    await TTSService.instance.falar(
      text,
      caller: this,
    );
    if (mounted) setState(() => _isSpeakingAudio = false);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final title = _lembrete?.titulo ?? cfg.defaultTitle;

    final hasPhoto = _lembrete?.categoria == 'medicacao' &&
        _lembrete?.medicamentoFotoPath != null &&
        _lembrete!.medicamentoFotoPath!.isNotEmpty;

    final hasInstructions = _lembrete?.medicamentoInstrucoes != null &&
        _lembrete!.medicamentoInstrucoes!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AlexFloatingHelpButton(
        textoExplicacao: cfg.detailedExplanation,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VolumeWarningBanner(),
            _buildTopBar(context, cfg),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    // 1. Banner do período do dia
                    _buildPeriodBanner(_lembrete?.horarioHour ?? DateTime.now().hour, cfg),
                    const SizedBox(height: 20),

                    // 2. Foto do medicamento ou ícone principal da categoria
                    if (hasPhoto)
                      _buildMedicinePhotoContainer(_lembrete!.medicamentoFotoPath!, cfg)
                    else
                      _buildPulsingIcon(cfg),

                    const SizedBox(height: 20),

                    // 4. Título Principal em Fonte Gigante com Alto Contraste
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: cfg.color,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Horário em Destaque Gigante
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cfg.color.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled, size: 28, color: cfg.color),
                          const SizedBox(width: 8),
                          Text(
                            _lembrete?.horarioFormatado ?? '00:00',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: cfg.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. Instruções Detalhadas / Observações
                    if (hasInstructions) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cfg.color, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: cfg.color.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: cfg.color, size: 30),
                                const SizedBox(width: 10),
                                Text(
                                  'COMO FAZER:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: cfg.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _lembrete!.medicamentoInstrucoes!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 6. Botão Gigante "🔊 OUVIR NOVAMENTE"
                    _buildListenAgainButton(cfg),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, _ReminderCategoryConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cfg.topBarTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
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

  Widget _buildPeriodBanner(int hour, _ReminderCategoryConfig cfg) {
    final title = PeriodHelper.getPeriodLabel(hour).toUpperCase();
    final icon = PeriodHelper.getPeriodIcon(hour);
    final bg = PeriodHelper.getPeriodColor(hour);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Text(
            'LEMBRETE DA $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenAgainButton(_ReminderCategoryConfig cfg) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: _speak,
        icon: Icon(
          _isSpeakingAudio ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
          size: 30,
          color: cfg.color,
        ),
        label: Text(
          _isSpeakingAudio ? 'FALANDO AGORA...' : 'OUVIR DE NOVO',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: cfg.color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cfg.color, width: 3),
          backgroundColor: cfg.color.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }



  Widget _buildMedicinePhotoContainer(String path, _ReminderCategoryConfig cfg) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: cfg.color, width: 5),
        boxShadow: [
          BoxShadow(
            color: cfg.color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          image: path.startsWith('assets/')
              ? AssetImage(path) as ImageProvider
              : path.startsWith('http')
              ? NetworkImage(path)
              : FileImage(File(path)),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(cfg.icon, size: 80, color: cfg.color),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon(_ReminderCategoryConfig cfg) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: cfg.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: cfg.color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: cfg.color, width: 4),
          ),
          child: Icon(cfg.icon, size: 72, color: cfg.color),
        ),
      ],
    );
  }


}

class _ReminderCategoryConfig {
  final IconData icon;
  final Color color;
  final String topBarTitle;
  final String defaultTitle;
  final String defaultSubtitle;
  final String detailedExplanation;
  final String Function(Lembrete lembrete, String timeStr) spokenText;
  final String Function() defaultSpokenText;

  const _ReminderCategoryConfig({
    required this.icon,
    required this.color,
    required this.topBarTitle,
    required this.defaultTitle,
    required this.defaultSubtitle,
    required this.detailedExplanation,
    required this.spokenText,
    required this.defaultSpokenText,
  });
}
