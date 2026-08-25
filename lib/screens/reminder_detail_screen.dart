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
import '../utils/app_image_helper.dart';

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
      final localFoto = await ElderlyProfileRepository.instance
          .getCachedPhotoPath();
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
          final inst =
              (l.medicamentoInstrucoes != null &&
                  l.medicamentoInstrucoes!.isNotEmpty)
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
        spokenText: (l, timeStr) => 'Refeição: ${l.titulo} $timeStr.',
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
        spokenText: (l, timeStr) => 'Exercício: ${l.titulo} $timeStr.',
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
        spokenText: (l, timeStr) => 'Hidratação: ${l.titulo} $timeStr.',
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
        spokenText: (l, timeStr) => 'Lembrete: ${l.titulo} $timeStr.',
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

    await TTSService.instance.falar(text, caller: this);
    if (mounted) setState(() => _isSpeakingAudio = false);
  }

  String _getRecorrenciaTexto(Lembrete l) {
    if (l.recorrencia == 'unico' || l.lembreteUnico) {
      return 'Lembrete único';
    } else if (l.recorrencia == 'semanal' || l.recorrenciaSemanal) {
      const diaNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      final dias = l.diasSemana
          .map((d) => d >= 1 && d <= 7 ? diaNomes[d - 1] : '')
          .where((s) => s.isNotEmpty)
          .join(', ');
      return dias.isNotEmpty ? 'Toda semana ($dias)' : 'Semanal';
    } else if (l.recorrencia == 'mensal' || l.recorrenciaMensal) {
      return 'Todo mês (dia ${l.diaMes ?? l.criadoEm.day})';
    } else if (l.recorrencia == 'intervalo' || l.recorrenciaIntervalo) {
      return 'A cada ${l.intervaloHoras ?? 8} horas';
    } else {
      return 'Todos os dias';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final title = _lembrete?.titulo ?? cfg.defaultTitle;

    final hasPhoto =
        _lembrete?.categoria == 'medicacao' &&
        _lembrete?.medicamentoFotoPath != null &&
        _lembrete!.medicamentoFotoPath!.isNotEmpty;

    final hasInstructions =
        _lembrete?.medicamentoInstrucoes != null &&
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                child: Column(
                  children: [
                    // Card 1: Hero Card do Lembrete
                    _buildHeroCard(cfg, title, hasPhoto),
                    const SizedBox(height: 24),

                    // Card 2: Voz e Orientações
                    _buildAudioAndInstructionsCard(cfg, hasInstructions),
                    const SizedBox(height: 28),

                    // Card 3: Botão Seguro para Gestão (Proteção contra Exclusão Acidental)
                    if (_lembrete != null) _buildManagementSection(cfg),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    _ReminderCategoryConfig cfg,
    String title,
    bool hasPhoto,
  ) {
    final visualStatus = _lembrete != null
        ? ReminderStateHelper.visualStatus(_lembrete!, now: DateTime.now())
        : ReminderStatus.scheduled;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (visualStatus) {
      case ReminderStatus.done:
      case ReminderStatus.doneWithPhoto:
      case ReminderStatus.caregiverConfirmed:
        statusText = 'CONCLUÍDO HOJE';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case ReminderStatus.late:
        statusText = 'ATRASADO';
        statusColor = AppColors.warning;
        statusIcon = Icons.warning_rounded;
        break;
      case ReminderStatus.missed:
        statusText = 'NÃO RESPONDIDO';
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusText = 'AGENDADO';
        statusColor = cfg.color;
        statusIcon = Icons.schedule_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cfg.color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner do período do dia no topo do card
          _buildPeriodBanner(
            _lembrete?.horarioHour ?? DateTime.now().hour,
            cfg,
          ),
          const SizedBox(height: 24),

          // Foto do medicamento ou ícone principal da categoria
          if (hasPhoto)
            _buildMedicinePhotoContainer(_lembrete!.medicamentoFotoPath!, cfg)
          else
            _buildPulsingIcon(cfg),
          const SizedBox(height: 24),

          // Título Principal em Fonte Gigante com Alto Contraste
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
          const SizedBox(height: 18),

          // Horário e Recorrência em Badges
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cfg.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cfg.color.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled, size: 26, color: cfg.color),
                    const SizedBox(width: 8),
                    Text(
                      _lembrete?.horarioFormatado ?? '00:00',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: cfg.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (_lembrete != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 22,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getRecorrenciaTexto(_lembrete!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Badge de Status do Lembrete
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: statusColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioAndInstructionsCard(
    _ReminderCategoryConfig cfg,
    bool hasInstructions,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 28, color: cfg.color),
              const SizedBox(width: 10),
              Text(
                'AJUDA E VOZ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Botão OUVIR COMO FAZER (quando existirem instruções textuais)
          if (hasInstructions) ...[
            GestureDetector(
              onTap: () {
                TTSService.instance.parar(caller: this);
                TTSService.instance.falar(
                  'Instruções de como fazer: ${_lembrete!.medicamentoInstrucoes!}',
                  caller: this,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: cfg.color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: cfg.color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OUVIR COMO FAZER',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Toque aqui para ouvir as orientações',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Botão Gigante OUVIR DE NOVO
          _buildListenAgainButton(cfg),

          // Botão IA para que serve (se for medicação)
          if (_lembrete?.categoria == 'medicacao') ...[
            const SizedBox(height: 16),
            _buildGeminiButton(cfg),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementSection(_ReminderCategoryConfig cfg) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton.icon(
        onPressed: () => _showManagementBottomSheet(context, cfg),
        icon: const Icon(Icons.settings_rounded, size: 28),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'GERENCIAR OU APAGAR LEMBRETE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurfaceVariant,
          side: BorderSide(color: AppColors.outlineVariant, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  void _showManagementBottomSheet(
    BuildContext context,
    _ReminderCategoryConfig cfg,
  ) {
    if (_lembrete == null) return;
    TTSService.instance.parar(caller: this);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.settings_rounded, size: 30, color: cfg.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configurações do Lembrete',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ações seguras para modificar ou apagar este lembrete:',
              style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Mudar Nome
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  TTSService.instance.parar(caller: this);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) =>
                        ElderlyEditTitleDialog(initialValue: _lembrete!.titulo),
                  );
                  if (result == null ||
                      result.isEmpty ||
                      result == _lembrete!.titulo) {
                    return;
                  }
                  await LembreteService.instance.atualizarTitulo(
                    _lembrete!.id,
                    result,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pronto. O nome foi trocado.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 28),
                label: const Text(
                  'MUDAR NOME DO LEMBRETE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cfg.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mudar Horário
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  TTSService.instance.parar(caller: this);
                  final picked = await showCustomTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _lembrete!.horarioHour,
                      minute: _lembrete!.horarioMinute,
                    ),
                  );
                  if (picked == null) {
                    return;
                  }
                  await LembreteService.instance.atualizarHorario(
                    _lembrete!.id,
                    picked.hour,
                    picked.minute,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pronto. O horário foi trocado.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.access_time_rounded, size: 28),
                label: const Text(
                  'MUDAR HORÁRIO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cfg.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Apagar Lembrete
            SizedBox(
              height: 60,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  TTSService.instance.parar(caller: this);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) =>
                        ElderlyDeleteReminderDialog(lembrete: _lembrete!),
                  );
                  if (confirm != true) {
                    return;
                  }
                  await LembreteService.instance.remover(_lembrete!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lembrete apagado.')),
                    );
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 28),
                label: const Text(
                  'APAGAR ESTE LEMBRETE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error, width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
      decoration: BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const Spacer(),
          Text(
            cfg.topBarTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              TTSService.instance.parar(caller: this);
              await Navigator.pushNamed(context, '/elderly-profile');
              _loadProfilePhoto();
            },
            child: ElderlyProfileAvatar(fotoPath: _fotoPath, size: 56),
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
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isSpeakingAudio ? 'FALANDO AGORA...' : 'OUVIR DE NOVO',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: cfg.color,
            ),
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
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.psychology, size: 30),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isFetchingExplanation ? 'PENSANDO...' : 'PARA QUE SERVE?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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

    await TTSService.instance.falar(
      "Vou perguntar ao médico virtual, só um momento.",
      caller: this,
    );

    final explanation = await GeminiService.explicarMedicamento(
      _lembrete!.titulo,
    );

    if (mounted) {
      setState(() {
        _isFetchingExplanation = false;
      });
      await TTSService.instance.falar(explanation, caller: this);
    }
  }

  Widget _buildMedicinePhotoContainer(
    String path,
    _ReminderCategoryConfig cfg,
  ) {
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
                          : AppImageHelper.resizedFileImage(
                              File(path),
                              maxWidth: 1200,
                              maxHeight: 1200,
                            ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 40,
                    ),
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
                : AppImageHelper.resizedFileImage(
                    File(path),
                    maxWidth: 400,
                    maxHeight: 400,
                  ),
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
