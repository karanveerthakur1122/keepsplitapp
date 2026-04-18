import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/liquid_glass_theme.dart';

class LiquidGlassElevated extends StatelessWidget {
  const LiquidGlassElevated({
    super.key,
    required this.child,
    this.borderRadius = 0,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final config = LiquidGlassConfig.elevated();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tintColor = isDark
        ? Colors.white.withValues(alpha: config.tintOpacity * 0.7)
        : config.tintColor.withValues(alpha: config.tintOpacity);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: config.borderOpacity * 0.4)
        : Colors.white.withValues(alpha: config.borderOpacity);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: config.blurAmount,
            sigmaY: config.blurAmount,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: tintColor,
              border: borderRadius > 0
                  ? Border.all(color: borderColor, width: 0.5)
                  : Border(
                      bottom: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
