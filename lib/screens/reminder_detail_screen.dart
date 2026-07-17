import 'package:flutter/material.dart';
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
    if (cat == 'refeicoes') {
      return _ReminderCategoryConfig(
        icon: Icons.restaurant,
        color: AppColors.mealsColor,
        topBarTitle: 'Hora de Comer',
        defaultTitle: 'HORA DE COMER',
        defaultSubtitle: _lembrete != null
            ? 'Refeição agendada para às ${_lembrete!.horarioFormatado}. Bom apetite!'
            : 'Sua refeição está pronta. Bom apetite!',
        detailedExplanation:
            'Olá, esta é a tela de detalhes da sua refeição. Aqui você pode ver qual refeição foi programada e o horário dela. Se for comer agora, aperte o botão verde escrito ENTENDI. Se quiser comer mais tarde, aperte o botão amarelo escrito ADIAR.',
        spokenText: (l, timeStr) =>
            'Hora de comer. ${l.titulo} agendado para às $timeStr. Por favor, faça sua refeição.',
        defaultSpokenText: () => 'Hora de comer. Sua refeição está pronta. Bom apetite!',
      );
    } else if (cat == 'exercicio') {
      return _ReminderCategoryConfig(
        icon: Icons.directions_walk,
        color: AppColors.tertiaryContainer,
        topBarTitle: 'Vamos nos Mexer',
        defaultTitle: 'HORA DO EXERCÍCIO',
        defaultSubtitle: _lembrete != null
            ? 'Atividade física agendada para às ${_lembrete!.horarioFormatado}. Vamos lá!'
            : 'Vamos nos movimentar!',
        detailedExplanation:
            'Olá, esta é a tela de detalhes do seu exercício. Aqui você pode ver o nome do exercício e o horário programado. Se for realizar a atividade agora, aperte o botão verde escrito ENTENDI. Se quiser fazer mais tarde, aperte o botão amarelo escrito ADIAR.',
        spokenText: (l, timeStr) =>
            'Hora de se mexer. ${l.titulo} agendado para às $timeStr. Vamos nos movimentar.',
        defaultSpokenText: () => 'Hora de se exercitar. Vamos nos movimentar!',
      );
    } else {
      return _ReminderCategoryConfig(
        icon: Icons.alarm,
        color: AppColors.primary,
        topBarTitle: 'Detalhes do Lembrete',
        defaultTitle: 'LEMBRETE',
        defaultSubtitle: _lembrete != null
            ? 'Lembrete agendado para às ${_lembrete!.horarioFormatado}.'
            : 'Atenção ao seu lembrete!',
        detailedExplanation:
            'Olá, esta é a tela de detalhes do seu lembrete. Se for realizar a atividade agora, aperte o botão verde escrito ENTENDI. Se quiser fazer mais tarde, aperte o botão amarelo escrito ADIAR.',
        spokenText: (l, timeStr) =>
            'Atenção ao seu lembrete. ${l.titulo} agendado para às $timeStr.',
        defaultSpokenText: () => 'Atenção ao seu lembrete!',
      );
    }
  }

  void _speak() {
    _hasSpoken = true;
    final cfg = _config;
    if (_lembrete != null) {
      final timeStr = PeriodHelper.getSpokenTime(_lembrete!.horarioHour, _lembrete!.horarioMinute);
      TTSService.instance.falar(
        cfg.spokenText(_lembrete!, timeStr),
        caller: this,
      );
    } else {
      TTSService.instance.falar(
        cfg.defaultSpokenText(),
        caller: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final title = _lembrete?.titulo ?? cfg.defaultTitle;

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    _buildPulsingIcon(cfg),
                    const SizedBox(height: 32),
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cfg.defaultSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_lembrete != null) {
                            await LembreteService.instance.concluir(_lembrete!.id);
                          }
                          TTSService.instance.parar(caller: this);
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle, size: 32),
                        label: const Text(
                          'ENTENDI',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cfg.color,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_lembrete != null) {
                            await LembreteService.instance.adiar(_lembrete!.id, 10);
                          }
                          TTSService.instance.parar(caller: this);
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.access_time, size: 24),
                        label: const Text(
                          'ADIAR (10 MINUTOS)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildSpeakerIndicator(cfg),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, _ReminderCategoryConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.arrow_back, color: cfg.color, size: 36),
            ),
          ),
          Expanded(
            child: Text(
              cfg.topBarTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cfg.color),
            ),
          ),
          Icon(Icons.volume_up, color: cfg.color, size: 28),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            child: Row(
              children: List.generate(4, (i) => Container(
                width: 4,
                height: [16, 24, 12, 20][i].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: cfg.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingIcon(_ReminderCategoryConfig cfg) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            color: cfg.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 140, height: 140,
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

  Widget _buildSpeakerIndicator(_ReminderCategoryConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hearing, size: 16, color: cfg.color),
                const SizedBox(width: 8),
                Text(
                  'ALTO-FALANTE ATIVO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: cfg.color),
                ),
              ],
            ),
          ),
        ],
      ),
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
