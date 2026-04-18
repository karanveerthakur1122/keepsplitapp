import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/liquid_glass_theme.dart';

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final config = LiquidGlassConfig.surface();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tintColor = isDark
        ? Colors.white.withValues(alpha: config.tintOpacity * 0.7)
        : config.tintColor.withValues(alpha: config.tintOpacity);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: config.borderOpacity * 0.5)
        : Colors.white.withValues(alpha: config.borderOpacity);

    final br = BorderRadius.circular(borderRadius);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: config.blurAmount,
            sigmaY: config.blurAmount,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              color: tintColor,
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
