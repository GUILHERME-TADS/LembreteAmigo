import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';

class MeExplicaButton extends StatelessWidget {
  final String textoExplicacao;
  final VoidCallback? onTapped;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const MeExplicaButton({
    super.key,
    required this.textoExplicacao,
    this.onTapped,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final txtColor = textColor ?? AppColors.primary;
    final bg = backgroundColor ?? AppColors.primary.withValues(alpha: 0.08);
    final border = borderColor ?? AppColors.primary.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: () {
        TTSService.instance.parar();
        if (onTapped != null) {
          onTapped!();
        }
        TTSService.instance.falar(
          textoExplicacao,
          caller: this,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over,
              color: txtColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Me explica',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: txtColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
