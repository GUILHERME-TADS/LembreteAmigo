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
            ? 'Medicamento agendado para às ${_lembrete!.horarioFormatado}.'
            : 'Sua medicação está no horário!',
        detailedExplanation:
            'Olá, esta é a tela de detalhes do seu remédio. Aqui você pode ver a foto, o horário e a instrução. Aperte o botão de alto-falante para ouvir tudo de novo.',
        spokenText: (l, timeStr) {
          final inst = (l.medicamentoInstrucoes != null && l.medicamentoInstrucoes!.isNotEmpty)
              ? ' Instrução: ${l.medicamentoInstrucoes}.'
              : '';
          return 'Hora do remédio. ${l.titulo} agendado para às $timeStr.$inst Por favor, tome seu medicamento.';
        },
        defaultSpokenText: () => 'Hora do remédio. Por favor, tome seu medicamento.',
      );
    } else if (cat == 'refeicoes') {
      return _ReminderCategoryConfig(
        icon: Icons.restaurant_rounded,
        color: AppColors.mealsColor,
        topBarTitle: 'Hora de Comer',
        defaultTitle: 'HORA DE COMER',
        defaultSubtitle: _lembrete != null
            ? 'Refeição agendada para às ${_lembrete!.horarioFormatado}. Bom apetite!'
            : 'Sua refeição está pronta. Bom apetite!',
        detailedExplanation:
            'Olá, esta é a tela de detalhes da sua refeição. Se for comer agora, aperte o botão verde escrito JÁ COMI OU ENTENDI.',
        spokenText: (l, timeStr) =>
            'Hora de comer. ${l.titulo} agendado para às $timeStr. Por favor, faça sua refeição.',
        defaultSpokenText: () => 'Hora de comer. Sua refeição está pronta. Bom apetite!',
      );
    } else if (cat == 'exercicio') {
      return _ReminderCategoryConfig(
        icon: Icons.directions_walk_rounded,
        color: AppColors.tertiaryContainer,
        topBarTitle: 'Vamos nos Mexer',
        defaultTitle: 'HORA DO EXERCÍCIO',
        defaultSubtitle: _lembrete != null
            ? 'Atividade física agendada para às ${_lembrete!.horarioFormatado}. Vamos lá!'
            : 'Vamos nos movimentar!',
        detailedExplanation:
            'Olá, esta é a tela do seu exercício. Aperte o botão verde para confirmar que vai fazer o exercício.',
        spokenText: (l, timeStr) =>
            'Hora de se mexer. ${l.titulo} agendado para às $timeStr. Vamos nos movimentar.',
        defaultSpokenText: () => 'Hora de se exercitar. Vamos nos movimentar!',
      );
    } else if (cat == 'hidratacao') {
      return _ReminderCategoryConfig(
        icon: Icons.water_drop_rounded,
        color: AppColors.voiceFeedbackBlue,
        topBarTitle: 'Hora da Hidratação',
        defaultTitle: 'HORA DA HIDRATAÇÃO',
        defaultSubtitle: _lembrete != null
            ? 'Lembrete de água agendado para às ${_lembrete!.horarioFormatado}.'
            : 'Hora de beber um copo d\'água!',
        detailedExplanation:
            'Olá! Beber água faz bem para a saúde. Aperte o botão verde assim que beber o seu copo d\'água.',
        spokenText: (l, timeStr) =>
            'Hora de beber água. ${l.titulo} agendado para às $timeStr.',
        defaultSpokenText: () => 'Hora de beber um copo d\'água!',
      );
    } else {
      return _ReminderCategoryConfig(
        icon: Icons.notifications_active_rounded,
        color: AppColors.primary,
        topBarTitle: 'Detalhes do Lembrete',
        defaultTitle: 'LEMBRETE',
        defaultSubtitle: _lembrete != null
            ? 'Lembrete agendado para às ${_lembrete!.horarioFormatado}.'
            : 'Atenção ao seu lembrete!',
        detailedExplanation:
            'Olá, esta é a tela do seu lembrete. Aperte no botão de alto-falante para ouvir as orientações por voz.',
        spokenText: (l, timeStr) =>
            'Atenção ao seu lembrete. ${l.titulo} agendado para às $timeStr.',
        defaultSpokenText: () => 'Atenção ao seu lembrete!',
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
                                  'INSTRUÇÕES:',
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

                    const SizedBox(height: 20),

                    // 7. Card de Afeto / Lembrete com Carinho
                    _buildTrustCard(cfg),

                    const SizedBox(height: 32),

                    // 8. Botão Princpal "✔️ JÁ TOMEI / ENTENDI" (Verde Semântico)
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          if (_lembrete != null) {
                            if (_lembrete!.categoria == 'medicacao' && !_lembrete!.concluido) {
                              TTSService.instance.parar(caller: this);
                              nav.pushReplacementNamed(
                                '/take-photo-confirmation',
                                arguments: _lembrete!.id,
                              );
                              return;
                            } else {
                              await LembreteService.instance.concluir(_lembrete!.id);
                            }
                          }
                          // Reforço Positivo por Voz
                          TTSService.instance.falar(
                            'Muito bem! Você cuidou da sua saúde com sucesso!',
                            caller: this,
                          );
                          if (mounted) nav.pop();
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 36),
                        label: Text(
                          _lembrete?.concluido == true
                              ? 'CONCLUÍDO ✔️'
                              : (_lembrete?.categoria == 'medicacao'
                                    ? 'JÁ TOMEI ✔️'
                                    : 'JÁ FIZ / ENTENDI ✔️'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32), // Verde Forte de Sucesso
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 9. Botão Secundário "⏰ MAIS TARDE (10 MIN)" (Amarelo Semântico)
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          if (_lembrete != null) {
                            await LembreteService.instance.adiar(_lembrete!.id, 10);
                          }
                          TTSService.instance.falar(
                            'Tudo bem! Vamos te lembrar novamente em 10 minutos.',
                            caller: this,
                          );
                          if (mounted) nav.pop();
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 30),
                        label: const Text(
                          'MAIS TARDE (10 MINUTOS)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF57F17), // Amarelo/Laranja Quente
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

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
    String title;
    IconData icon;
    Color bg;

    if (hour >= 0 && hour < 6) {
      title = 'MADRUGADA';
      icon = Icons.nightlight_round;
      bg = const Color(0xFF2C3E50);
    } else if (hour >= 6 && hour < 12) {
      title = 'MANHÃ';
      icon = Icons.wb_sunny_rounded;
      bg = const Color(0xFFE67E22);
    } else if (hour >= 12 && hour < 18) {
      title = 'TARDE';
      icon = Icons.brightness_5_rounded;
      bg = const Color(0xFFD35400);
    } else {
      title = 'NOITE';
      icon = Icons.bedtime_rounded;
      bg = const Color(0xFF1E3C72);
    }

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
            'PERÍODO DA $title',
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
          _isSpeakingAudio ? 'FALANDO AGORA...' : '🔊 OUVIR DE NOVO',
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

  Widget _buildTrustCard(_ReminderCategoryConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
          SizedBox(width: 8),
          Text(
            'Lembrete agendado com carinho para você',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
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
