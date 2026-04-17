import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/liquid_glass_theme.dart';

class LiquidGlassWidget extends StatefulWidget {
  const LiquidGlassWidget({
    super.key,
    required this.child,
    this.config,
    this.borderRadius = 18,
    this.animateOnPress = true,
    this.onTap,
  });

  final Widget child;
  final LiquidGlassConfig? config;
  final double borderRadius;
  final bool animateOnPress;
  final VoidCallback? onTap;

  @override
  State<LiquidGlassWidget> createState() => _LiquidGlassWidgetState();
}

class _LiquidGlassWidgetState extends State<LiquidGlassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LiquidGlassConfig get _config =>
      widget.config ??
      LiquidGlassTheme.maybeOf(context) ??
      LiquidGlassConfig.surface();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _config;

    final tintColor = isDark
        ? Colors.white.withValues(alpha: config.tintOpacity * 0.7)
        : config.tintColor.withValues(alpha: config.tintOpacity);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: config.borderOpacity * 0.5)
        : Colors.white.withValues(alpha: config.borderOpacity);

    final br = BorderRadius.circular(widget.borderRadius);

    Widget glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: liquidGlassShadows(context),
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: br,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: config.blurAmount,
              sigmaY: config.blurAmount,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: br,
                color: tintColor,
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.animateOnPress || widget.onTap != null) {
      glass = GestureDetector(
        onTapDown: widget.animateOnPress ? (_) => _controller.forward() : null,
        onTapUp: widget.animateOnPress
            ? (_) {
                _controller.reverse();
                widget.onTap?.call();
              }
            : null,
        onTapCancel:
            widget.animateOnPress ? () => _controller.reverse() : null,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: glass,
        ),
      );
    }

    return glass;
  }
}
