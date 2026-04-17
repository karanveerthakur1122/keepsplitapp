import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Thin wrapper around the expensive-but-beautiful `liquid_glass_renderer`
/// shader, with monochrome black-and-white presets tuned for this app.
///
/// Use sparingly — each instance creates a refraction texture for its
/// entire area, so reserve this for a few hero surfaces (FAB, app header,
/// maybe the editor sheet drag handle area). Keep the rest on the cheap
/// `BackdropFilter`-based liquid-glass widgets.
///
/// The glass is tinted:
/// - **Light mode**: subtle **black** tint so the glass pops off a white
///   backdrop.
/// - **Dark mode**: subtle **white** tint so the glass glows against a
///   dark backdrop.
///
/// No color tint is ever used — this is strictly a monochrome look that
/// borrows all color from whatever is behind it.
class RealLiquidGlass extends StatelessWidget {
  const RealLiquidGlass({
    super.key,
    required this.child,
    this.shape = const LiquidGlassSquircle(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    this.thickness = 16,
    this.blur = 6,
    this.lightIntensity = 1.2,
    this.outlineIntensity = 0.25,
    this.ambientStrength = 0.02,
    this.glassContainsChild = false,
  });

  /// Convenience constructor for a circular glass button (FAB).
  const RealLiquidGlass.circle({
    super.key,
    required this.child,
    this.thickness = 22,
    this.blur = 8,
    this.lightIntensity = 1.35,
    this.outlineIntensity = 0.35,
    this.ambientStrength = 0.02,
    this.glassContainsChild = false,
  }) : shape = const LiquidGlassEllipse();

  /// Convenience constructor for a pill-shaped bar (app header).
  RealLiquidGlass.pill({
    super.key,
    required this.child,
    double borderRadius = 22,
    this.thickness = 14,
    this.blur = 5,
    this.lightIntensity = 1.15,
    this.outlineIntensity = 0.2,
    this.ambientStrength = 0.02,
    this.glassContainsChild = false,
  }) : shape = LiquidGlassSquircle(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        );

  final Widget child;
  final LiquidGlassShape shape;
  final double thickness;
  final double blur;
  final double lightIntensity;
  final double outlineIntensity;
  final double ambientStrength;
  final bool glassContainsChild;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Monochrome tint: black on light bg, white on dark bg. Alpha kept low
    // so refraction of the content beneath stays the star of the effect.
    final Color glassColor = isDark
        ? const Color(0x1AFFFFFF) // ~10% white
        : const Color(0x1A000000); // ~10% black

    return LiquidGlass(
      shape: shape,
      blur: blur,
      glassContainsChild: glassContainsChild,
      settings: LiquidGlassSettings(
        thickness: thickness,
        glassColor: glassColor,
        lightAngle: 0.5 * math.pi, // top-down highlight
        lightIntensity: lightIntensity,
        ambientStrength: ambientStrength,
        outlineIntensity: outlineIntensity,
        chromaticAberration: 0.0, // keep it clean, no colored fringes
      ),
      child: child,
    );
  }
}
