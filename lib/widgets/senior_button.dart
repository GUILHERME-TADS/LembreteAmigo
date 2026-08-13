import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class SeniorButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.secondaryContainer;
    final fg = textColor ?? AppColors.onSecondaryContainer;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      child: Semantics(
        button: true,
        label: label,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            elevation: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 32),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeniorBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onTap;

  const SeniorBottomNav({super.key, this.selectedIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: AppColors.secondaryContainer, width: 4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home, 'Início', 0),
          _navItem(context, Icons.medical_services, 'Remédios', 1),
          _navItem(context, Icons.contact_support, 'Ajuda', 2),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final selected = selectedIndex == index;
    final textScale = MediaQuery.textScalerOf(context).scale(14);
    return GestureDetector(
      onTap: () => onTap?.call(index),
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.secondaryContainer : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                  size: 28,
                ),
                if (textScale <= 22) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.05,
                      color: selected
                          ? AppColors.onSecondaryContainer
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
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
                        children: const [
                          Icon(Icons.volume_up, size: 20, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Ouvir',
                            style: TextStyle(
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
