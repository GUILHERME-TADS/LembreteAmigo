import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/index.dart';
import '../utils/period_helper.dart';
import '../services/tts_service.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final LembreteService _service = LembreteService.instance;

  @override
  void initState() {
    super.initState();
    _service.carregar();
  }

  @override
  void dispose() {
    TTSService.instance.parar(caller: this);
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
              child: ValueListenableBuilder<List<Lembrete>>(
                valueListenable: _service.notifier,
                builder: (context, lembretes, _) {
                  final hidratacao = lembretes
                      .where((l) => l.categoria == 'hidratacao')
                      .toList()
                    ..sort((a, b) => (a.horarioHour * 60 + a.horarioMinute)
                        .compareTo(b.horarioHour * 60 + b.horarioMinute));

                  final concluidos =
                      hidratacao.where((l) => l.concluido).length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Hora de beber água!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AudioPlayerCard(
                          accentColor: AppColors.voiceFeedbackBlue,
                          subtitle: 'Ouça todos os lembretes',
                          textsToSpeak: hidratacao.map((l) =>
                              '${l.titulo} às ${PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute)}').toList(),
                        ),
                        const SizedBox(height: 24),
                        if (hidratacao.isEmpty)
                          _buildEmptyState()
                        else ...[
                          for (final lembrete in hidratacao) ...[
                            _buildWaterCard(lembrete: lembrete),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 24),
                          _buildProgressCard(concluidos, hidratacao.length),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              TTSService.instance.parar(caller: this);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text(
                              'VOLTAR',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.voiceFeedbackBlue,
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
                color: AppColors.voiceFeedbackBlue, size: 32),
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Text(
            'Hidratação',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.voiceFeedbackBlue,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              TTSService.instance.parar(caller: this);
              TTSService.instance.falar(
                'Aqui você pode ver a quantidade de água que bebeu hoje.',
                caller: this,
              );
            },
            child: const AlexAvatar(size: 40),
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.voiceFeedbackBlue,
            ),
            child: const Icon(Icons.water_drop, color: Colors.white),
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
          Icon(Icons.water_drop,
              color: AppColors.voiceFeedbackBlue.withValues(alpha: 0.4),
              size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nenhum lembrete de hidratação',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione lembretes para\nbeber água',
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

  Widget _buildWaterCard({required Lembrete lembrete}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(
          color: lembrete.concluido
              ? AppColors.tertiaryFixedDim
              : AppColors.outlineVariant,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lembrete.concluido
                  ? AppColors.tertiaryFixedDim.withValues(alpha: 0.3)
                  : AppColors.voiceFeedbackBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              lembrete.concluido ? Icons.check_circle : Icons.water_drop,
              color: lembrete.concluido
                  ? AppColors.onTertiaryFixedVariant
                  : AppColors.voiceFeedbackBlue,
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
                        size: 24, color: AppColors.voiceFeedbackBlue),
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
          if (!lembrete.concluido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.voiceFeedbackBlue,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Text(
                'BEBER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
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
        color: AppColors.voiceFeedbackBlue.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.voiceFeedbackBlue, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'META DO DIA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.voiceFeedbackBlue,
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
                      color: AppColors.voiceFeedbackBlue,
                    ),
                  ),
                  const Text(
                    'copos',
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
                  const AlwaysStoppedAnimation(AppColors.voiceFeedbackBlue),
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
                const AlwaysStoppedAnimation(AppColors.voiceFeedbackBlue),
          ),
          Icon(Icons.water_drop, color: AppColors.voiceFeedbackBlue, size: 36),
        ],
      ),
    );
  }
}
