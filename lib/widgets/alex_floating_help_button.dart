import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'alex_avatar.dart';

class AlexFloatingHelpButton extends StatefulWidget {
  final String textoExplicacao;
  final FutureOr<void> Function()? onTapped;

  const AlexFloatingHelpButton({
    super.key,
    required this.textoExplicacao,
    this.onTapped,
  });

  @override
  State<AlexFloatingHelpButton> createState() => _AlexFloatingHelpButtonState();
}

class _AlexFloatingHelpButtonState extends State<AlexFloatingHelpButton>
    with TickerProviderStateMixin {
  static const double _avatarSize = 68;
  static const double _gap = 12;
  static const double _screenEdgePadding = 12;
  static Offset _globalDragOffset = Offset.zero;

  final GlobalKey _avatarAnchorKey = GlobalKey();
  late final AnimationController _glowController;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Size? _lastViewportSize;
  EdgeInsets? _lastViewportPadding;
  bool _entryAnimationStarted = false;
  bool _reduceMotion = false;
  bool _isHandlingTap = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;

    if (_reduceMotion != reduceMotion) {
      _reduceMotion = reduceMotion;
      if (_reduceMotion) {
        _entryController.value = 1;
        _glowController
          ..stop()
          ..reset();
      }
    }

    if (!_entryAnimationStarted) {
      _entryAnimationStarted = true;
      if (_reduceMotion) {
        _entryController.value = 1;
      } else {
        _entryController.forward();
      }
    }

    if (_lastViewportSize != media.size ||
        _lastViewportPadding != media.padding) {
      _lastViewportSize = media.size;
      _lastViewportPadding = media.padding;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureAvatarIsVisible();
      });
    }
  }

  @override
  void dispose() {
    unawaited(TTSService.instance.parar(caller: this));
    _glowController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(bool isThisSpeaking) async {
    if (_isHandlingTap) return;
    _isHandlingTap = true;

    try {
      try {
        await HapticFeedback.mediumImpact();
      } catch (error) {
        debugPrint('Vibração indisponível ao tocar no Alex: $error');
      }
      if (isThisSpeaking) {
        await TTSService.instance.parar(caller: this);
        return;
      }

      await TTSService.instance.parar();
      final onTapped = widget.onTapped;
      if (onTapped != null) await onTapped();
      if (!mounted) return;

      final speechStarted = Completer<void>();
      void handleSpeakingChange() {
        if (!speechStarted.isCompleted &&
            TTSService.instance.isSpeaking &&
            TTSService.instance.activeCaller == this) {
          speechStarted.complete();
        }
      }

      TTSService.instance.speakingNotifier.addListener(handleSpeakingChange);
      final speechFinished = TTSService.instance.falar(
        widget.textoExplicacao,
        caller: this,
      );
      handleSpeakingChange();

      try {
        await Future.any<void>([speechStarted.future, speechFinished]);
      } finally {
        TTSService.instance.speakingNotifier.removeListener(
          handleSpeakingChange,
        );
      }

      unawaited(
        speechFinished.catchError((Object error, StackTrace stackTrace) {
          debugPrint('Erro ao falar a explicação do Alex: $error');
        }),
      );
    } catch (error) {
      debugPrint('Erro ao iniciar a explicação do Alex: $error');
    } finally {
      _isHandlingTap = false;
    }
  }

  void _syncAnimation(bool isThisSpeaking) {
    if (_reduceMotion) {
      if (_glowController.isAnimating || _glowController.value != 0) {
        _glowController
          ..stop()
          ..reset();
      }
      return;
    }

    if (isThisSpeaking && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!isThisSpeaking && _glowController.isAnimating) {
      _glowController
        ..stop()
        ..reset();
    }
  }

  Rect? _avatarRect() {
    final renderObject = _avatarAnchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final rect = _avatarRect();
    if (rect == null) return;

    final media = MediaQuery.of(context);
    final safeLeft = media.padding.left + _screenEdgePadding;
    final safeTop = media.padding.top + _screenEdgePadding;
    final safeRight =
        media.size.width - media.padding.right - _screenEdgePadding;
    final safeBottom =
        media.size.height - media.padding.bottom - _screenEdgePadding;

    var dx = details.delta.dx;
    var dy = details.delta.dy;

    if (rect.left + dx < safeLeft) dx = safeLeft - rect.left;
    if (rect.right + dx > safeRight) dx = safeRight - rect.right;
    if (rect.top + dy < safeTop) dy = safeTop - rect.top;
    if (rect.bottom + dy > safeBottom) dy = safeBottom - rect.bottom;

    final nextOffset = _globalDragOffset + Offset(dx, dy);
    if (nextOffset.dx > 0) dx -= nextOffset.dx;
    if (nextOffset.dy > 0) dy -= nextOffset.dy;

    if (dx == 0 && dy == 0) return;
    setState(() {
      _globalDragOffset += Offset(dx, dy);
    });
  }

  double _leftEdgeDragOffset(MediaQueryData media) {
    final defaultAvatarLeft =
        media.size.width - media.padding.right - 16 - _avatarSize;
    final safeLeft = media.padding.left + _screenEdgePadding;
    return math.min(0, safeLeft - defaultAvatarLeft);
  }

  void _handlePanEnd(DragEndDetails details) {
    final rect = _avatarRect();
    final media = MediaQuery.of(context);
    final moveToLeft = rect != null && rect.center.dx < media.size.width / 2;

    setState(() {
      _globalDragOffset = Offset(
        moveToLeft ? _leftEdgeDragOffset(media) : 0,
        _globalDragOffset.dy,
      );
      _isDragging = false;
    });
  }

  void _ensureAvatarIsVisible() {
    final rect = _avatarRect();
    if (rect == null) return;

    final media = MediaQuery.of(context);
    final safeLeft = media.padding.left + _screenEdgePadding;
    final safeTop = media.padding.top + _screenEdgePadding;
    final safeRight =
        media.size.width - media.padding.right - _screenEdgePadding;
    final safeBottom =
        media.size.height - media.padding.bottom - _screenEdgePadding;

    var correctionX = 0.0;
    var correctionY = 0.0;
    if (rect.left < safeLeft) correctionX = safeLeft - rect.left;
    if (rect.right > safeRight) correctionX = safeRight - rect.right;
    if (rect.top < safeTop) correctionY = safeTop - rect.top;
    if (rect.bottom > safeBottom) correctionY = safeBottom - rect.bottom;

    final restingX = !_isDragging && _globalDragOffset.dx < 0
        ? _leftEdgeDragOffset(media)
        : _globalDragOffset.dx;
    if (correctionX == 0 &&
        correctionY == 0 &&
        restingX == _globalDragOffset.dx) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final corrected =
          Offset(restingX, _globalDragOffset.dy) +
          Offset(correctionX, correctionY);
      _globalDragOffset = Offset(
        math.min(0, corrected.dx),
        math.min(0, corrected.dy),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TTSService.instance.speakingNotifier,
      builder: (context, isGlobalSpeaking, child) {
        final isThisSpeaking =
            isGlobalSpeaking && TTSService.instance.activeCaller == this;
        _syncAnimation(isThisSpeaking);

        final media = MediaQuery.of(context);
        final isFlipped = _globalDragOffset.dx < 0;
        final availableBubbleWidth =
            media.size.width -
            media.padding.horizontal -
            _avatarSize -
            _gap -
            48;
        final bubbleWidth = availableBubbleWidth.clamp(90.0, 190.0);
        final contentWidth = bubbleWidth + _gap + _avatarSize;

        final bubble = SizedBox(
          width: bubbleWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isThisSpeaking ? AppColors.error : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isFlipped ? 4 : 20),
                bottomRight: Radius.circular(isFlipped ? 20 : 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isThisSpeaking
                      ? Icons.stop_circle_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isThisSpeaking ? 'PARAR DE FALAR' : 'ME EXPLICA',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final avatar = SizedBox(
          key: _avatarAnchorKey,
          width: _avatarSize,
          height: _avatarSize,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isThisSpeaking && !_reduceMotion
                      ? [
                          BoxShadow(
                            color: AppColors.secondaryFixed.withValues(
                              alpha: 0.4 + (_glowController.value * 0.3),
                            ),
                            blurRadius: 12 + (_glowController.value * 12),
                            spreadRadius: 2 + (_glowController.value * 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: AlexAvatar(
                  size: _avatarSize,
                  animate: true,
                  activeCaller: this,
                ),
              );
            },
          ),
        );

        final buttonContent = _isDragging
            ? avatar
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: isFlipped
                    ? [avatar, const SizedBox(width: _gap), bubble]
                    : [bubble, const SizedBox(width: _gap), avatar],
              );

        final draggableButton = Semantics(
          button: true,
          label: isThisSpeaking ? 'Parar de falar' : 'Me explica',
          hint: isThisSpeaking
              ? 'Interrompe a explicação em voz alta'
              : 'Lê em voz alta uma explicação desta tela',
          child: ExcludeSemantics(
            child: GestureDetector(
              key: const ValueKey<String>('alex-help-button-hit-area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleTap(isThisSpeaking),
              onPanStart: (_) {
                if (!_entryController.isCompleted) {
                  _entryController.value = 1;
                }
                setState(() => _isDragging = true);
              },
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onPanCancel: () => _handlePanEnd(DragEndDetails()),
              child: buttonContent,
            ),
          ),
        );

        final safeLeft = media.padding.left + _screenEdgePadding;
        final restingRightPadding = isFlipped
            ? math.max(
                0.0,
                media.size.width -
                    media.padding.right -
                    16 -
                    contentWidth -
                    safeLeft,
              )
            : 0.0;
        final rightPadding = _isDragging
            ? -_globalDragOffset.dx
            : restingRightPadding;

        return Padding(
          padding: EdgeInsets.only(
            right: rightPadding,
            bottom: -_globalDragOffset.dy,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: isFlipped
                  ? Alignment.bottomLeft
                  : Alignment.bottomRight,
              child: draggableButton,
            ),
          ),
        );
      },
    );
  }
}
