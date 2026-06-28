import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/index.dart';
import '../utils/period_helper.dart';

class CustomRemindersScreen extends StatefulWidget {
  const CustomRemindersScreen({super.key});

  @override
  State<CustomRemindersScreen> createState() => _CustomRemindersScreenState();
}

class _CustomRemindersScreenState extends State<CustomRemindersScreen> {
  final LembreteService _service = LembreteService.instance;

  @override
  void initState() {
    super.initState();
    _service.carregar();
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
              child: ValueListenableBuilder<List<Lembrete>>(
                valueListenable: _service.notifier,
                builder: (context, lembretes, _) {
                  final personalizados = lembretes
                      .where((l) => l.categoria == 'personalizado')
                      .toList()
                    ..sort((a, b) => (a.horarioHour * 60 + a.horarioMinute)
                        .compareTo(b.horarioHour * 60 + b.horarioMinute));

                  final concluidos =
                      personalizados.where((l) => l.concluido).length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Seus lembretes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AudioPlayerCard(
                          accentColor: AppColors.customColor,
                          subtitle: 'Ouça todos os lembretes',
                          textsToSpeak: personalizados.map((l) =>
                              '${l.titulo} às ${PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute)}').toList(),
                        ),
                        const SizedBox(height: 24),
                        if (personalizados.isEmpty)
                          _buildEmptyState()
                        else ...[
                          for (final lembrete in personalizados) ...[
                            AudioExpandableCard(
                              cardBuilder: (context, onPlay, isPlaying) =>
                                  _buildCustomCard(
                                lembrete: lembrete,
                                onPlay: onPlay,
                                isPlaying: isPlaying,
                              ),
                              accentColor: AppColors.customColor,
                              textToSpeak: '${lembrete.titulo} às ${PeriodHelper.getSpokenTime(lembrete.horarioHour, lembrete.horarioMinute)}',
                              borderColor: lembrete.concluido
                                  ? AppColors.tertiaryFixedDim
                                  : AppColors.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 24),
                          _buildProgressCard(concluidos, personalizados.length),
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
                              backgroundColor: AppColors.customColor,
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
                  );
                },
              ),
            ),
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
            icon: const Icon(Icons.arrow_back,
                color: AppColors.customColor, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Personalizados',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.customColor,
            ),
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.customColor,
            ),
            child: const Icon(Icons.notifications, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none,
              color: AppColors.customColor.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nenhum lembrete personalizado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lembretes que não se encaixam\nem outras categorias aparecem aqui',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCard({
    required Lembrete lembrete,
    VoidCallback? onPlay,
    bool isPlaying = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lembrete.concluido
                      ? AppColors.tertiaryFixedDim.withValues(alpha: 0.3)
                      : AppColors.customColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lembrete.concluido
                      ? Icons.check_circle
                      : Icons.notifications,
                  color: lembrete.concluido
                      ? AppColors.onTertiaryFixedVariant
                      : AppColors.customColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lembrete.titulo,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 24, color: AppColors.customColor),
                        const SizedBox(width: 8),
                        Text(
                          lembrete.horarioFormatado,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onPlay != null)
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.customColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      color: AppColors.customColor,
                      size: 24,
                    ),
                  ),
                ),
              if (onPlay != null && lembrete.concluido)
                const SizedBox(width: 12),
              if (lembrete.concluido)
                const Icon(Icons.check_circle,
                    color: AppColors.tertiaryFixedDim, size: 32),
            ],
          ),
        );
  }

  Widget _buildProgressCard(int concluidos, int total) {
    final valor = total > 0 ? concluidos / total : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.customColor.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.customColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'LEMBRETES DO DIA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.customColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressCircle(concluidos, total),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '$concluidos de $total',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.customColor,
                    ),
                  ),
                  const Text(
                    'lembretes',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: valor,
              minHeight: 12,
              backgroundColor: AppColors.outlineVariant,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.customColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle(int current, int total) {
    final valor = total > 0 ? current / total : 0.0;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: valor,
            strokeWidth: 8,
            backgroundColor: AppColors.outlineVariant,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.customColor),
          ),
          const Icon(Icons.notifications,
              color: AppColors.customColor, size: 24),
        ],
      ),
    );
  }
}
