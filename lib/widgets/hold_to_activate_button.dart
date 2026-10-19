import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Botão com salvaguarda "Pressione e Segure" (Hold-to-Activate).
/// Projetado para prevenir acionamentos acidentais em ações de emergência/críticas,
/// mantendo facilidade e clareza absoluta para idosos com baixo letramento.
class HoldToActivateButton extends StatefulWidget {
  final String label;
  final String activeLabel;
  final IconData icon;
  final Duration holdDuration;
  final VoidCallback onTriggered;
  final Color? backgroundColor;
  final Color? progressColor;
  final Color? textColor;
  final double minHeight;
  final String? helperText;
  final String? activeHelperText;
  final String semanticsHint;
  final bool showHelperText;

  const HoldToActivateButton({
    super.key,
    required this.label,
    this.activeLabel = 'Mantenha pressionado...',
    this.icon = Icons.emergency,
    this.holdDuration = const Duration(seconds: 3),
    required this.onTriggered,
    this.backgroundColor,
    this.progressColor,
    this.textColor,
    this.minHeight = 96,
    this.helperText,
    this.activeHelperText,
    this.semanticsHint = 'Pressione e segure para ativar. Solte para cancelar.',
    this.showHelperText = true,
  });

  @override
  State<HoldToActivateButton> createState() => _HoldToActivateButtonState();
}

class _HoldToActivateButtonState extends State<HoldToActivateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;
  int _lastSecondsLeft = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _controller.addListener(_onProgressUpdate);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _resetHold();
      }
    });
  }

  void _onProgressUpdate() {
    if (!_isHolding) return;
    final totalSec = widget.holdDuration.inSeconds;
    final secondsLeft = (totalSec * (1.0 - _controller.value)).ceil();
    if (secondsLeft != _lastSecondsLeft && secondsLeft > 0) {
      _lastSecondsLeft = secondsLeft;
      HapticFeedback.mediumImpact();
    }
  }

  void _startHold() {
    if (_isHolding) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _lastSecondsLeft = widget.holdDuration.inSeconds;
    });
    _controller.forward(from: 0.0);
  }

  void _resetHold() {
    if (!_isHolding && _controller.value == 0) return;
    if (mounted) {
      setState(() {
        _isHolding = false;
      });
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onProgressUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? AppColors.error;
    final progressCol = widget.progressColor ?? const Color(0xFFFF8A80);
    final textCol = widget.textColor ?? Colors.white;

    final secondsRemaining =
        (widget.holdDuration.inSeconds * (1.0 - _controller.value)).ceil();

    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      hint: widget.semanticsHint,
      onLongPress: _startHold,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _startHold(),
        onPointerUp: (_) => _resetHold(),
        onPointerCancel: (_) => _resetHold(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _isHolding ? 0.97 : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: widget.minHeight),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.35),
                      blurRadius: _isHolding ? 8 : 16,
                      offset: _isHolding
                          ? const Offset(0, 3)
                          : const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl - 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Barra de progresso interna
                      if (_isHolding)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _controller.value.clamp(0.0, 1.0),
                            child: Container(
                              color: progressCol.withValues(alpha: 0.4),
                            ),
                          ),
                        ),

                      // Conteúdo do botão
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon,
                                size: 38,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isHolding
                                        ? '${widget.activeLabel} ($secondsRemaining s)'
                                        : widget.label,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: textCol,
                                      height: 1.1,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (widget.showHelperText) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _isHolding
                                          ? widget.activeHelperText ??
                                                'Solte para cancelar o socorro'
                                          : widget.helperText ??
                                                'Pressione e segure por ${widget.holdDuration.inSeconds} segundos',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textCol.withValues(alpha: 0.9),
                                        height: 1.2,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
