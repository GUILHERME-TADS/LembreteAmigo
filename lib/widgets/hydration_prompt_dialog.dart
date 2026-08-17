import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/vibration_service.dart';
import '../services/wellbeing_service.dart';
import '../theme/app_theme.dart';
import 'senior_button.dart';

class HydrationPromptDialog extends StatefulWidget {
  final String? reminderTitle;

  const HydrationPromptDialog({super.key, this.reminderTitle});

  static Future<bool?> show(BuildContext context, {String? reminderTitle}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HydrationPromptDialog(reminderTitle: reminderTitle),
    );
  }

  @override
  State<HydrationPromptDialog> createState() => _HydrationPromptDialogState();
}

class _HydrationPromptDialogState extends State<HydrationPromptDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _drank = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSService.instance.falar(
        'Remédio confirmado! Que tal beber um copo de água agora para fazer bem à sua saúde?',
        caller: this,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onDrankWater() async {
    if (_drank) return;
    setState(() => _drank = true);
    await VibrationService.successPattern();
    await WellbeingService.instance.logHydration();
    if (!mounted) return;
    TTSService.instance.falar('Muito bem! Água faz muito bem.', caller: this);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Colors.white,
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF38BDF8), width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 58,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Muito bem! 💙',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Aproveite para tomar\n1 copo de água fresco agora.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SeniorButton(
              label: '💧 Tomei a água!',
              backgroundColor: const Color(0xFF0284C7),
              textColor: Colors.white,
              onPressed: _onDrankWater,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Depois eu tomo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
