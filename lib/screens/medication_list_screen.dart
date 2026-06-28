import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lembrete.dart';
import '../services/lembrete_service.dart';
import '../widgets/index.dart';
import '../utils/period_helper.dart';
import '../services/tts_service.dart';

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
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

  String _descreverMedicamento(Lembrete l) {
    final spokenTime = PeriodHelper.getSpokenTime(l.horarioHour, l.horarioMinute);
    var desc = '${l.titulo} às $spokenTime.';
    if (l.medicamentoForma != null && l.medicamentoCor != null) {
      final formaFeminina = (l.medicamentoForma == 'capsula' || l.medicamentoForma == 'pomada' || l.medicamentoForma == 'gotas');
      final formaLabel = l.medicamentoForma == 'capsula'
          ? 'cápsula'
          : l.medicamentoForma == 'comprimido'
              ? 'comprimido'
              : l.medicamentoForma == 'gotas'
                  ? 'gotas'
                  : 'pomada';
      final corLabel = l.medicamentoCor!;
      var corAjustada = corLabel;
      if (formaFeminina) {
        if (corLabel == 'vermelho') corAjustada = 'vermelha';
        if (corLabel == 'amarelo') corAjustada = 'amarela';
        if (corLabel == 'branco') corAjustada = 'branca';
      }
      desc += ' Tomar em formato de $formaLabel na cor $corAjustada.';
    }
    return desc;
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
                  final medicacoes = lembretes
                      .where((l) => l.categoria == 'medicacao')
                      .toList()
                    ..sort((a, b) => (a.horarioHour * 60 + a.horarioMinute)
                        .compareTo(b.horarioHour * 60 + b.horarioMinute));

                  final concluidos =
                      medicacoes.where((l) => l.concluido).length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Veja o que tomar hoje',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AudioPlayerCard(
                          accentColor: AppColors.medicationsColor,
                          subtitle: 'Ouça todos os lembretes',
                          textsToSpeak: medicacoes.map((l) => _descreverMedicamento(l)).toList(),
                        ),
                        const SizedBox(height: 24),
                        if (medicacoes.isEmpty)
                          _buildEmptyState()
                        else ...[
                          for (final lembrete in medicacoes) ...[
                            AudioExpandableCard(
                              cardBuilder: (context, onPlay, isPlaying) =>
                                  _buildMedicationCard(
                                lembrete: lembrete,
                                onPlay: onPlay,
                                isPlaying: isPlaying,
                              ),
                              accentColor: AppColors.medicationsColor,
                              textToSpeak: _descreverMedicamento(lembrete),
                              audioPath: lembrete.audioPath,
                              borderColor: lembrete.concluido
                                  ? AppColors.tertiaryFixedDim
                                  : AppColors.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildAddCard(),
                          const SizedBox(height: 24),
                          _buildProgressCard(concluidos, medicacoes.length),
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
                              backgroundColor: AppColors.medicationsColor,
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
                color: AppColors.medicationsColor, size: 32),
            onPressed: () {
              TTSService.instance.parar(caller: this);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Text(
            'Meus Remédios',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.medicationsColor,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              TTSService.instance.parar(caller: this);
              TTSService.instance.falar(
                'Aqui estão os seus remédios de hoje.',
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
              color: AppColors.medicationsColor,
            ),
            child: const Icon(Icons.medication, color: Colors.white),
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
          Icon(Icons.medication,
              color: AppColors.medicationsColor.withValues(alpha: 0.4),
              size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nenhum remédio cadastrado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione seus remédios para\nver aqui',
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

  Widget _buildMedicationCard({
    required Lembrete lembrete,
    VoidCallback? onPlay,
    bool isPlaying = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: lembrete.concluido
                  ? AppColors.tertiaryFixedDim.withValues(alpha: 0.3)
                  : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant, width: 2),
            ),
            child: Center(
              child: lembrete.concluido
                  ? const Icon(
                      Icons.check_circle,
                      color: AppColors.onTertiaryFixedVariant,
                      size: 32,
                    )
                  : PillVisualizer(
                      forma: lembrete.medicamentoForma,
                      cor: lembrete.medicamentoCor,
                      size: 36,
                      fotoPath: lembrete.medicamentoFotoPath,
                    ),
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
                        size: 24, color: AppColors.medicationsColor),
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
                  color: AppColors.medicationsColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  color: AppColors.medicationsColor,
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

  Widget _buildAddCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.add_circle, color: AppColors.onSurfaceVariant, size: 32),
          SizedBox(height: 12),
          Text(
            'Novo remédio',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
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
        color: AppColors.medicationsColor.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.medicationsColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'REMEDIOS DO DIA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.medicationsColor,
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
                      color: AppColors.medicationsColor,
                    ),
                  ),
                  const Text(
                    'remédios',
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
                  const AlwaysStoppedAnimation(AppColors.medicationsColor),
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
                const AlwaysStoppedAnimation(AppColors.medicationsColor),
          ),
          const Icon(Icons.medication,
              color: AppColors.medicationsColor, size: 24),
        ],
      ),
    );
  }
}
