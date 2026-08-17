import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

/// Botão de Segurança que exige segurar por um período (Hold-to-Confirm)
/// Ideal para SOS / Emergências e Ações Críticas de Idosos
class SeniorHoldButton extends StatefulWidget {
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
  State<SeniorHoldButton> createState() => _SeniorHoldButtonState();
}

class _SeniorHoldButtonState extends State<SeniorHoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _controller.reset();
        if (mounted) setState(() => _isHolding = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isHolding) return;
    HapticFeedback.mediumImpact();
    setState(() => _isHolding = true);
    _controller.forward(from: 0.0);
  }

  void _onTapCancel() {
    if (!_isHolding) return;
    _controller.reverse();
    setState(() => _isHolding = false);
  }

  void _onTapUp(TapUpDetails details) {
    _onTapCancel();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: widget.height),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: widget.foregroundColor.withValues(alpha: 0.3),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.backgroundColor.withValues(
                    alpha: _isHolding ? 0.4 : 0.2,
                  ),
                  blurRadius: _isHolding ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Barra de preenchimento progressivo ao segurar
                if (progress > 0)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.foregroundColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.xl - 2),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              value: progress > 0 ? progress : 0,
                              strokeWidth: 4,
                              backgroundColor: widget.foregroundColor.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.foregroundColor,
                              ),
                            ),
                          ),
                          Icon(
                            widget.icon,
                            size: 30,
                            color: widget.foregroundColor,
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: widget.foregroundColor,
                                height: 1.2,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _isHolding
                                    ? 'Segure firme...'
                                    : widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: widget.foregroundColor.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card tátil de alta legibilidade para idosos
class SeniorTactileCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const SeniorTactileCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.surfaceContainerLowest;
    final border = borderColor ?? AppColors.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

