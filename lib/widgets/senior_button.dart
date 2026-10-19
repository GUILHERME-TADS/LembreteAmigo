import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hold_to_activate_button.dart';
import '../theme/app_theme.dart';

class SeniorButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final VoidCallback? onPressed;

  const SeniorButton({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height = 96,
    this.onPressed,
  });

  @override
  State<SeniorButton> createState() => _SeniorButtonState();
}

class _SeniorButtonState extends State<SeniorButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? AppColors.secondaryContainer;
    final fg = widget.textColor ?? AppColors.onSecondaryContainer;

    return AnimatedScale(
      scale: _isPressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: widget.height),
        decoration: AppDecorations.tactileButton(
          color: bg,
          borderColor: fg.withValues(alpha: 0.25),
          borderRadius: AppRadius.xl,
          isPressed: _isPressed,
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: widget.label,
            child: InkWell(
              onTap: widget.onPressed == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      widget.onPressed!();
                    },
              onHighlightChanged: (highlighted) {
                if (mounted) setState(() => _isPressed = highlighted);
              },
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 36, color: fg),
                      const SizedBox(width: 14),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: fg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SeniorInputField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final VoidCallback? onTapAudio;
  final VoidCallback? onTapMic;
  final bool isListening;

  const SeniorInputField({
    super.key,
    required this.label,
    this.placeholder,
    this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.inputFormatters,
    this.keyboardType,
    this.onTapAudio,
    this.onTapMic,
    this.isListening = false,
  });

  @override
  State<SeniorInputField> createState() => _SeniorInputFieldState();
}

class _SeniorInputFieldState extends State<SeniorInputField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.05,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onTapMic != null) ...[
                  GestureDetector(
                    onTap: widget.onTapMic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isListening
                            ? AppColors.error
                            : AppColors.onCustomContainer,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (widget.isListening
                                        ? AppColors.error
                                        : AppColors.onCustomContainer)
                                    .withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isListening ? Icons.stop : Icons.mic_none,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isListening ? 'Parar' : 'Falar',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.onTapAudio != null)
                  GestureDetector(
                    onTap: widget.onTapAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volume_up,
                            size: 20,
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ouvir',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.onPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: widget.isListening
                ? AppColors.error.withValues(alpha: 0.08)
                : AppColors.surfaceContainerLow,
            border: Border.all(
              color: widget.isListening
                  ? AppColors.error
                  : AppColors.outlineVariant,
              width: widget.isListening ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    widget.prefixIcon,
                    color: widget.isListening
                        ? AppColors.error
                        : AppColors.primary,
                    size: 26,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  obscureText: _obscureText,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isListening
                        ? 'Fale agora...'
                        : widget.placeholder,
                    hintStyle: TextStyle(
                      color: widget.isListening
                          ? AppColors.error
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: widget.isListening
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (widget.onTapMic != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: widget.isListening
                        ? AppColors.error
                        : AppColors.onCustomContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.isListening
                                    ? AppColors.error
                                    : AppColors.onCustomContainer)
                                .withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: widget.onTapMic,
                    tooltip: widget.isListening
                        ? 'Parar gravação'
                        : 'Ditar por voz',
                    icon: Icon(
                      widget.isListening ? Icons.stop : Icons.mic_none,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              if (widget.isPassword)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.outline,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mantém a API de confirmação para idosos usando o controle compartilhado.
class SeniorHoldButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Duration holdDuration;
  final VoidCallback onTriggered;
  final double height;

  const SeniorHoldButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.holdDuration = const Duration(seconds: 2),
    required this.onTriggered,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) => HoldToActivateButton(
    label: label,
    activeLabel: 'SEGURE',
    icon: icon,
    holdDuration: holdDuration,
    onTriggered: onTriggered,
    backgroundColor: backgroundColor,
    progressColor: foregroundColor.withValues(alpha: 0.2),
    textColor: foregroundColor,
    minHeight: height,
    helperText: subtitle,
    activeHelperText: subtitle == null ? null : 'Segure firme...',
    semanticsHint: 'Pressione e segure para confirmar esta ação.',
    showHelperText: subtitle != null,
  );
}
