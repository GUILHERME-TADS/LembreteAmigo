import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
}

extension ResponsiveContext on BuildContext {
  Size get viewportSize => MediaQuery.sizeOf(this);

  bool get isCompactWidth => viewportSize.width < AppBreakpoints.compact;
  bool get isCompactHeight => viewportSize.height < 600;
  bool get isLandscape => viewportSize.width > viewportSize.height;

  double responsiveValue({
    required double compact,
    required double regular,
    double? expanded,
  }) {
    final width = viewportSize.width;
    if (width >= AppBreakpoints.medium && expanded != null) return expanded;
    return width < AppBreakpoints.compact ? compact : regular;
  }
}

/// Keeps the application usable on very wide browser and tablet viewports.
///
/// The nested [MediaQuery] is important: routes must see the constrained
/// viewport rather than the physical browser width.
class ResponsiveAppViewport extends StatelessWidget {
  const ResponsiveAppViewport({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.expanded,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.size.width <= maxWidth) return child;

    final constrainedSize = Size(maxWidth, mediaQuery.size.height);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          height: mediaQuery.size.height,
          child: MediaQuery(
            data: mediaQuery.copyWith(size: constrainedSize),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Scrollable page content that fills the viewport when short and scrolls
/// when content or accessibility text scaling needs more vertical space.
class ResponsiveScrollView extends StatelessWidget {
  const ResponsiveScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth = 720,
    this.alwaysFillViewport = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;
  final bool alwaysFillViewport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - resolvedPadding.vertical,
        );

        Widget content = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );

        if (alwaysFillViewport) {
          content = ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: IntrinsicHeight(child: content),
          );
        }

        return SingleChildScrollView(
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: content,
        );
      },
    );
  }
}

/// Switches a horizontal group to a vertical layout when its children would
/// become too narrow.
class ResponsiveButtonGroup extends StatelessWidget {
  const ResponsiveButtonGroup({
    super.key,
    required this.children,
    this.spacing = 12,
    this.stackBelow = 420,
  });

  final List<Widget> children;
  final double spacing;
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacing(children, vertical: true),
          );
        }
        return Row(children: _rowChildren(children));
      },
    );
  }

  List<Widget> _withSpacing(List<Widget> items, {required bool vertical}) {
    final result = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      if (index > 0) {
        result.add(
          vertical ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
      result.add(items[index]);
    }
    return result;
  }

  List<Widget> _rowChildren(List<Widget> items) {
    final result = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      if (index > 0) result.add(SizedBox(width: spacing));
      result.add(Expanded(child: items[index]));
    }
    return result;
  }
}
