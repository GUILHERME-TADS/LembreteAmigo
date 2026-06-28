import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/index.dart';
import '../utils/period_helper.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersScreenState();
}

class _AllRemindersScreenState extends State<AllRemindersScreen> {
  List<Lembrete> _voiceReminders = [];

  @override
  void initState() {
    super.initState();
    TTSService.instance.init();
    _loadReminders();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  void _loadReminders() {
    final list = LembreteService.instance.lembretes.toList();
    list.sort((a, b) {
      final aMin = a.horarioHour * 60 + a.horarioMinute;
      final bMin = b.horarioHour * 60 + b.horarioMinute;
      return aMin.compareTo(bMin);
    });
    _voiceReminders = list;
  }

  void _onLembretesChanged() {
    if (mounted) {
      setState(() => _loadReminders());
    }
  }

  (IconData, Color, Color) _categoriaIcon(String categoria) {
    switch (categoria) {
      case 'medicacao':
        return (Icons.medication, AppColors.medicationsColor, AppColors.medicationsColor);
      case 'refeicoes':
        return (Icons.restaurant, AppColors.mealsColor, AppColors.mealsColor);
      case 'exercicio':
        return (Icons.directions_walk, AppColors.tertiaryContainer, AppColors.tertiaryContainer);
      case 'hidratacao':
        return (Icons.water_drop, AppColors.voiceFeedbackBlue, AppColors.voiceFeedbackBlue);
      default:
        return (Icons.notifications, AppColors.secondaryContainer, AppColors.primary);
    }
  }

  void _stopAllAudioAndTts() {
    TTSService.instance.parar(caller: this);
    AudioManager.activeIdNotifier.value = null;
  }

  @override
  void dispose() {
    _stopAllAudioAndTts();
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const VolumeWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Todos os lembretes do dia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ordenado por horário',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AudioPlayerCard(
                      subtitle: 'Ouça todos os lembretes',
                      audioPath: _voiceReminders.isNotEmpty
                          ? _voiceReminders.last.audioPath
                          : null,
                      textsToSpeak: _voiceReminders.map((l) =>
                          '${l.titulo} às ${PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute)}').toList(),
                    ),
                    if (_voiceReminders.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Meus lembretes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._voiceReminders.map((r) {
                        final (icon, iconBg, accentColor) = _categoriaIcon(r.categoria);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReminderWithAudio(
                            icon: icon,
                            iconBg: iconBg,
                            iconColor: Colors.white,
                            accentColor: accentColor,
                            title: r.titulo,
                            time: r.horarioFormatado,
                            audioPath: r.audioPath,
                            status: r.concluido
                                ? ReminderStatus.done
                                : ReminderStatus.scheduled,
                            onTap: () async {
                              _stopAllAudioAndTts();
                              if (!r.concluido) {
                                SystemSound.play(SystemSoundType.click);
                                HapticFeedback.vibrate();
                              }
                              await LembreteService.instance.alternarConclusao(r.id);
                            },
                          ),
                        );
                      }),
                    ],
                    if (_voiceReminders.isEmpty) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: AppColors.outlineVariant),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhum lembrete criado',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use o botão de voz na tela inicial para criar lembretes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          'VOLTAR',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 32),
            onPressed: () {
              _stopAllAudioAndTts();
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Text(
            'Todos os Lembretes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              _stopAllAudioAndTts();
              TTSService.instance.falar(
                'Aqui estão todos os seus lembretes de hoje.',
                caller: this,
              );
            },
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              _stopAllAudioAndTts();
              Navigator.pushNamed(context, '/elderly-profile');
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.primaryContainer, width: 2),
                ),
              ),
              child: const Icon(Icons.person, color: AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 2)),
      ),
      child: Row(
        children: [
          _bottomNavItem(Icons.home, 'Início', false, () {
            _stopAllAudioAndTts();
            Navigator.pushNamedAndRemoveUntil(context, '/elderly-home', (route) => false);
          }),
          _bottomNavItem(Icons.list_alt, 'Lembretes', true, null),
          _bottomNavItem(Icons.help_center, 'Ajuda', false, () {
            _stopAllAudioAndTts();
            Navigator.pushNamed(context, '/elderly-help');
          }),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool selected, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                  color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
