import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lembrete.dart';
import '../theme/app_theme.dart';

/// Card de Lembrete estilo Blíster / Porta-Comprimidos Realista.
/// Facilita a identificação visual por idosos e pessoas com baixo letramento.
class BlisterReminderCard extends StatefulWidget {
  final Lembrete lembrete;
  final VoidCallback? onConfirm;
  final VoidCallback? onPlayAudio;
  final VoidCallback? onTap;
  final bool isNext;

  const BlisterReminderCard({
    super.key,
    required this.lembrete,
    this.onConfirm,
    this.onPlayAudio,
    this.onTap,
    this.isNext = false,
  });

  @override
  State<BlisterReminderCard> createState() => _BlisterReminderCardState();
}

class _BlisterReminderCardState extends State<BlisterReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _popController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  void _handlePopTap() {
    // Efeito tátil duplo de rompimento do blíster
    HapticFeedback.heavyImpact();
    _popController.forward(from: 0.0).then((_) {
      HapticFeedback.lightImpact();
    });
    if (widget.onTap != null) widget.onTap!();
  }

  IconData _getCategoryIcon() {
    switch (widget.lembrete.categoria) {
      case LembreteCategoria.medicacao:
        return Icons.medication_rounded;
      case LembreteCategoria.hidratacao:
        return Icons.water_drop_rounded;
      case LembreteCategoria.refeicoes:
        return Icons.restaurant_rounded;
      case LembreteCategoria.exercicio:
        return Icons.directions_walk_rounded;
      default:
        return Icons.access_time_filled_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (widget.lembrete.categoria) {
      case LembreteCategoria.medicacao:
        return const Color(0xFF7B1FA2);
      case LembreteCategoria.hidratacao:
        return const Color(0xFF0288D1);
      case LembreteCategoria.refeicoes:
        return const Color(0xFFE65100);
      case LembreteCategoria.exercicio:
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();
    final isConcluido = widget.lembrete.concluido ||
        widget.lembrete.status == LembreteStatus.concluido;

    return Semantics(
      label:
          '${widget.lembrete.horarioFormatado} - ${widget.lembrete.titulo}. Categoria: ${LembreteCategoria.nome(widget.lembrete.categoria)}. ${isConcluido ? "Concluído" : "Pendente"}',
      button: true,
      child: GestureDetector(
        onTap: _handlePopTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isConcluido
                  ? const Color(0xFFF1F8E9)
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isConcluido
                    ? const Color(0xFF81C784)
                    : widget.isNext
                        ? categoryColor
                        : AppColors.outlineVariant.withValues(alpha: 0.6),
                width: widget.isNext ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isNext
                      ? categoryColor.withValues(alpha: 0.2)
                      : AppColors.shadow.withValues(alpha: 0.08),
                  blurRadius: widget.isNext ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 0,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Ícone em formato de Alvéolo / Blíster
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isConcluido
                        ? const Color(0xFF2E7D32)
                        : categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isConcluido
                          ? const Color(0xFF1B5E20)
                          : categoryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isConcluido
                        ? const Icon(
                            Icons.check_circle_rounded,
                            size: 36,
                            color: Colors.white,
                          )
                        : Icon(
                            _getCategoryIcon(),
                            size: 36,
                            color: categoryColor,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Detalhes do Lembrete
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              widget.lembrete.horarioFormatado,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.isNext)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE082),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Text(
                                'PRÓXIMO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.lembrete.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isConcluido
                              ? const Color(0xFF558B2F)
                              : AppColors.onSurface,
                          decoration:
                              isConcluido ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botão Rápido de Áudio
                if (widget.onPlayAudio != null &&
                    widget.lembrete.audioPath != null &&
                    widget.lembrete.audioPath!.isNotEmpty) ...[
                  IconButton.filledTonal(
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      backgroundColor:
                          AppColors.voiceFeedbackBlue.withValues(alpha: 0.15),
                      foregroundColor: AppColors.voiceFeedbackBlue,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onPlayAudio!();
                    },
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Ouvir instrução por voz',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
