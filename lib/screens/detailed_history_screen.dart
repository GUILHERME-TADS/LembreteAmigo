import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/supervisor_bottom_nav.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/reminder_with_audio.dart';
import '../services/lembrete_service.dart';

class DetailedHistoryScreen extends StatefulWidget {
  const DetailedHistoryScreen({super.key});

  @override
  State<DetailedHistoryScreen> createState() => _DetailedHistoryScreenState();
}

class _DetailedHistoryScreenState extends State<DetailedHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadLembretes();
    LembreteService.instance.notifier.addListener(_onLembretesChanged);
  }

  @override
  void dispose() {
    LembreteService.instance.notifier.removeListener(_onLembretesChanged);
    super.dispose();
  }

  void _onLembretesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLembretes() async {
    await LembreteService.instance.carregar();
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return 'Hoje, ${now.day} de ${meses[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final list = LembreteService.instance.lembretes;
    final total = list.length;
    final concluido = list.where((l) => l.concluido).length;
    final percentage = total > 0 ? ((concluido / total) * 100).toInt() : 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SupervisorBottomNav(
        selected: SupervisorNavDestination.history,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Histórico Detalhado',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _dateSection(_getCurrentDateFormatted(), percentage),
                    const SizedBox(height: 8),
                    AudioPlayerCard(
                      accentColor: AppColors.primary,
                      subtitle: 'Ouça o resumo do dia',
                      textsToSpeak: list.isEmpty
                          ? ['Nenhum lembrete cadastrado para hoje.']
                          : [
                              'Resumo das atividades de hoje:',
                              ...list.map(
                                (l) =>
                                    '${l.titulo} às ${l.horarioFormatado}. Status: ${l.concluido ? "Concluído" : "Pendente"}.',
                              ),
                            ],
                    ),
                    const SizedBox(height: 16),
                    if (list.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 64,
                              color: AppColors.outline,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Sem atividades cadastradas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Os lembretes programados para o idoso aparecerão aqui no histórico assim que cadastrados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...list.map((lembrete) {
                        IconData icon = Icons.notifications;
                        Color iconBg = AppColors.customColor.withValues(
                          alpha: 0.15,
                        );
                        Color iconColor = AppColors.customColor;
                        Color accentColor = AppColors.customColor;
                        String categoryLabel = 'Personalizado';

                        switch (lembrete.categoria) {
                          case 'medicacao':
                            icon = Icons.medication;
                            iconBg = AppColors.medicationsColor.withValues(
                              alpha: 0.15,
                            );
                            iconColor = AppColors.medicationsColor;
                            accentColor = AppColors.medicationsColor;
                            categoryLabel = 'Remédio';
                            break;
                          case 'refeicoes':
                            icon = Icons.restaurant;
                            iconBg = AppColors.mealsColor.withValues(
                              alpha: 0.15,
                            );
                            iconColor = AppColors.mealsColor;
                            accentColor = AppColors.mealsColor;
                            categoryLabel = 'Refeição';
                            break;
                          case 'exercicio':
                            icon = Icons.directions_walk;
                            iconBg = AppColors.tertiaryContainer.withValues(
                              alpha: 0.15,
                            );
                            iconColor = AppColors.tertiaryContainer;
                            accentColor = AppColors.tertiaryContainer;
                            categoryLabel = 'Exercício';
                            break;
                          case 'hidratacao':
                            icon = Icons.water_drop;
                            iconBg = AppColors.voiceFeedbackBlue.withValues(
                              alpha: 0.15,
                            );
                            iconColor = AppColors.voiceFeedbackBlue;
                            accentColor = AppColors.voiceFeedbackBlue;
                            categoryLabel = 'Água';
                            break;
                        }
                        final status = reminderVisualStatusFromLembrete(
                          lembrete,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ReminderWithAudio(
                            icon: icon,
                            iconBg: iconBg,
                            iconColor: iconColor,
                            title: lembrete.titulo,
                            time: lembrete.horarioFormatado,
                            status: status,
                            accentColor: accentColor,
                            audioPath: lembrete.audioPath,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/supervisor-reminder-detail',
                                arguments: {
                                  'title': lembrete.titulo,
                                  'time': lembrete.horarioFormatado,
                                  'iconData': icon,
                                  'accentColor': accentColor,
                                  'category': categoryLabel,
                                },
                              );
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/monthly-reports'),
                  icon: const Icon(Icons.assessment, size: 24),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VER RELATÓRIOS MENSAIS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          ),
          const Expanded(
            child: Text(
              'Lembrete Amigo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
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

  Widget _dateSection(String date, int pct) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixedDim,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$pct% Concluído',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onTertiaryFixedVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
