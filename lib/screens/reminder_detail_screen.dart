import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../services/gemini_service.dart';
import '../services/elderly_profile_repository.dart';
import '../utils/period_helper.dart';
import '../widgets/index.dart';
import '../widgets/custom_time_picker.dart';
import 'elderly_profile_screen.dart';

class ReminderDetailScreen extends StatefulWidget {
  const ReminderDetailScreen({super.key});

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  Lembrete? _lembrete;
  bool _hasSpoken = false;
  bool _isSpeakingAudio = false;
  bool _isFetchingExplanation = false;
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final localFoto =
          await ElderlyProfileRepository.instance.getCachedPhotoPath();
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
            'Olá! Esta é a tela do seu remédio. Aqui você pode ver a foto, o horário e como tomar. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) {
          final inst = (l.medicamentoInstrucoes != null && l.medicamentoInstrucoes!.isNotEmpty)
              ? ' Como tomar: ${l.medicamentoInstrucoes}.'
              : '';
          return 'Remédio: ${l.titulo} $timeStr.$inst';
        },
        defaultSpokenText: () => 'Hora do remédio.',
      );
    } else if (cat == 'refeicoes') {
      return _ReminderCategoryConfig(
        icon: Icons.restaurant_rounded,
        color: AppColors.mealsColor,
        topBarTitle: 'Hora da Refeição',
        defaultTitle: 'HORA DA REFEIÇÃO',
        defaultSubtitle: _lembrete != null
            ? 'Refeição marcada para às ${_lembrete!.horarioFormatado}. Bom apetite!'
            : 'Está na hora da sua refeição!',
        detailedExplanation:
            'Olá! Esta é a tela da sua refeição. Aqui você pode ver o horário e o que comer. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) =>
            'Refeição: ${l.titulo} $timeStr.',
        defaultSpokenText: () => 'Hora da refeição.',
      );
    } else if (cat == 'exercicio') {
      return _ReminderCategoryConfig(
        icon: Icons.directions_walk_rounded,
        color: AppColors.tertiaryContainer,
        topBarTitle: 'Hora do Exercício',
        defaultTitle: 'HORA DO EXERCÍCIO',
        defaultSubtitle: _lembrete != null
            ? 'Exercício marcado para às ${_lembrete!.horarioFormatado}. Vamos lá!'
            : 'Está na hora do seu exercício!',
        detailedExplanation:
            'Olá! Esta é a tela do seu exercício. Aqui você pode ver o horário e o que fazer. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) =>
            'Exercício: ${l.titulo} $timeStr.',
        defaultSpokenText: () => 'Hora do exercício.',
      );
    } else if (cat == 'hidratacao') {
      return _ReminderCategoryConfig(
        icon: Icons.water_drop_rounded,
        color: AppColors.voiceFeedbackBlue,
        topBarTitle: 'Hora da Hidratação',
        defaultTitle: 'HORA DA HIDRATAÇÃO',
        defaultSubtitle: _lembrete != null
            ? 'Hidratação marcada para às ${_lembrete!.horarioFormatado}.'
            : 'Está na hora da sua hidratação!',
        detailedExplanation:
            'Olá! Esta é a tela da sua hidratação. Aqui você pode ver o horário e quanta água beber. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) =>
            'Hidratação: ${l.titulo} $timeStr.',
        defaultSpokenText: () => 'Hora da hidratação.',
      );
    } else {
      return _ReminderCategoryConfig(
        icon: Icons.notifications_active_rounded,
        color: AppColors.primary,
        topBarTitle: 'Hora do Lembrete',
        defaultTitle: 'HORA DO LEMBRETE',
        defaultSubtitle: _lembrete != null
            ? 'Lembrete marcado para às ${_lembrete!.horarioFormatado}.'
            : 'Está na hora do seu lembrete!',
        detailedExplanation:
            'Olá! Esta é a tela do seu lembrete. Aqui você pode ver o horário e o que fazer. Aperte o botão de ouvir para eu falar de novo.',
        spokenText: (l, timeStr) =>
            'Lembrete: ${l.titulo} $timeStr.',
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
            PeriodHelper.getSpokenTimeWithPreposition(
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

                    if (_lembrete?.categoria == 'medicacao') ...[
                      const SizedBox(height: 16),
                      _buildGeminiButton(cfg),
                    ],

                    if (_lembrete != null) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            TTSService.instance.parar(caller: this);
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) => ElderlyEditTitleDialog(initialValue: _lembrete!.titulo),
                            );
                            if (result == null || result.isEmpty || result == _lembrete!.titulo) return;
                            await LembreteService.instance.atualizarTitulo(_lembrete!.id, result);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pronto. O nome foi trocado.')));
                          },
                          icon: const Icon(Icons.edit, size: 28),
                          label: const Text('MUDAR NOME', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cfg.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            TTSService.instance.parar(caller: this);
                            final picked = await showCustomTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _lembrete!.horarioHour,
                                minute: _lembrete!.horarioMinute,
                              ),
                            );
                            if (picked == null) return;
                            await LembreteService.instance.atualizarHorario(
                              _lembrete!.id,
                              picked.hour,
                              picked.minute,
                            );
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pronto. O horário foi trocado.')));
                          },
                          icon: const Icon(Icons.access_time, size: 28),
                          label: const Text('MUDAR HORÁRIO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cfg.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            TTSService.instance.parar(caller: this);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => ElderlyDeleteReminderDialog(lembrete: _lembrete!),
                            );
                            if (confirm != true) return;
                            await LembreteService.instance.remover(_lembrete!.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lembrete apagado.')));
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.delete_forever, size: 28),
                          label: const Text('APAGAR LEMBRETE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error, width: 3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],

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

  Widget _buildGeminiButton(_ReminderCategoryConfig cfg) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isFetchingExplanation ? null : _explicarRemedio,
        icon: _isFetchingExplanation 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Icon(Icons.psychology, size: 30),
        label: Text(
          _isFetchingExplanation ? 'PENSANDO...' : 'PARA QUE SERVE?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _explicarRemedio() async {
    if (_lembrete == null) return;
    TTSService.instance.parar(caller: this);
    setState(() {
      _isFetchingExplanation = true;
    });

    await TTSService.instance.falar("Vou perguntar ao médico virtual, só um momento.", caller: this);

    final explanation = await GeminiService.explicarMedicamento(_lembrete!.titulo);
    
    if (mounted) {
      setState(() {
        _isFetchingExplanation = false;
      });
      await TTSService.instance.falar(explanation, caller: this);
    }
  }



  Widget _buildMedicinePhotoContainer(String path, _ReminderCategoryConfig cfg) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image(
                      image: path.startsWith('assets/')
                          ? AssetImage(path) as ImageProvider
                          : path.startsWith('http')
                          ? NetworkImage(path)
                          : FileImage(File(path)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 40),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
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
