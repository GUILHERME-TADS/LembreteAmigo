import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'elderly_profile_avatar.dart';

/// Modal animado de discagem com voz acolhedora do Alex e cancelamento rápido para idosos.
class CallingFeedbackDialog extends StatefulWidget {
  final String contactName;
  final String? fotoUrl;
  final String? callTypeLabel; // "Ligação Normal", "Vídeo", "WhatsApp"
  final VoidCallback onCallConfirmed;

  const CallingFeedbackDialog({
    super.key,
    required this.contactName,
    this.fotoUrl,
    this.callTypeLabel = 'Ligação',
    required this.onCallConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required String contactName,
    String? fotoUrl,
    String? callTypeLabel,
    required VoidCallback onCallConfirmed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CallingFeedbackDialog(
        contactName: contactName,
        fotoUrl: fotoUrl,
        callTypeLabel: callTypeLabel,
        onCallConfirmed: onCallConfirmed,
      ),
    );
  }

  @override
  State<CallingFeedbackDialog> createState() => _CallingFeedbackDialogState();
}

class _CallingFeedbackDialogState extends State<CallingFeedbackDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _autoDialTimer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    HapticFeedback.heavyImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Chamando ${widget.contactName}. Por favor, aguarde na linha.',
        caller: this,
      );
    });

    // Disca após 1.8 segundos dando tempo de ver/ouvir a confirmação
    _autoDialTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && !_cancelled) {
        Navigator.of(context).pop();
        widget.onCallConfirmed();
      }
    });
  }

  @override
  void dispose() {
    _autoDialTimer?.cancel();
    _pulseController.dispose();
    TTSService.instance.parar(caller: this);
    super.dispose();
  }

  void _cancelCall() {
    _cancelled = true;
    _autoDialTimer?.cancel();
    HapticFeedback.mediumImpact();
    TTSService.instance.falar('Ligação cancelada.', caller: this);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppColors.primary, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tipo de chamada badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              widget.callTypeLabel ?? 'Ligação',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Foto pulsante
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: 0.2 + (_pulseController.value * 0.25),
                        ),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: ElderlyProfileAvatar(
                    fotoPath: widget.fotoUrl,
                    size: 110,
                    borderWidth: 4,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Nome e Status
          Text(
            widget.contactName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Chamando agora...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Botão Cancelar Gigante
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _cancelCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              icon: const Icon(Icons.call_end_rounded, size: 28),
              label: const Text(
                'CANCELAR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
