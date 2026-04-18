import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/liquid_glass_theme.dart';

class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(16),
    this.enable3DTilt = true,
    this.config,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsets padding;
  final bool enable3DTilt;
  final LiquidGlassConfig? config;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0;
  double _tiltY = 0;

  late AnimationController _pressController;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerEvent event, Size size) {
    if (!widget.enable3DTilt) return;
    final dx = (event.localPosition.dx / size.width - 0.5) * 2;
    final dy = (event.localPosition.dy / size.height - 0.5) * 2;
    setState(() {
      _tiltX = dy * 3;
      _tiltY = -dx * 3;
    });
  }

  void _onPointerExit() {
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
    });
  }

  LiquidGlassConfig get _config =>
      widget.config ?? LiquidGlassConfig.surface();

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

    return AnimatedBuilder(
      animation: _pressAnim,
      builder: (context, child) {
        final scale = _pressAnim.value;
        final radX = _tiltX * math.pi / 180;
        final radY = _tiltY * math.pi / 180;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(radX)
          ..rotateY(radY)
          ..scale(scale);

        return Transform(
          transform: matrix,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Listener(
        onPointerMove: (e) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) _onPointerMove(e, box.size);
        },
        child: MouseRegion(
          onExit: (_) => _onPointerExit(),
          child: GestureDetector(
            onTapDown: (_) => _pressController.forward(),
            onTapUp: (_) {
              _pressController.reverse();
              widget.onTap?.call();
            },
            onTapCancel: () => _pressController.reverse(),
            onLongPress: widget.onLongPress,
            // Outer DecoratedBox carries the drop shadow. It has to sit
            // OUTSIDE the ClipRRect — otherwise the shadow would be clipped
            // by the same rounded rect and never paint. Dual layer: a
            // tight, dark layer for the contact shadow and a softer,
            // larger one for ambient depth.
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: br,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: br,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: config.blurAmount,
                      sigmaY: config.blurAmount,
                    ),
                    child: Container(
                      padding: widget.padding,
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
            ),
          ),
        ),
      ),
    );
  }
}
