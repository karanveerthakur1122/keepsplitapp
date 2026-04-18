import 'package:flutter/material.dart';

class LiquidGlassConfig {
  const LiquidGlassConfig({
    required this.distortionScale,
    required this.blurAmount,
    required this.tintColor,
    required this.tintOpacity,
    required this.borderOpacity,
    this.specularIntensity = 0.0,
    this.innerGlow = 0.0,
  });

  final double distortionScale;
  final double blurAmount;
  final Color tintColor;
  final double tintOpacity;
  final double borderOpacity;
  final double specularIntensity;
  final double innerGlow;

  factory LiquidGlassConfig.surface() {
    return const LiquidGlassConfig(
      distortionScale: 12,
      blurAmount: 10,
      tintColor: Color(0xFFFFFFFF),
      tintOpacity: 0.10,
      borderOpacity: 0.18,
      specularIntensity: 0.02,
      innerGlow: 0.04,
    );
  }

  factory LiquidGlassConfig.elevated() {
    return const LiquidGlassConfig(
      distortionScale: 14,
      blurAmount: 14,
      tintColor: Color(0xFFFFFFFF),
      tintOpacity: 0.14,
      borderOpacity: 0.22,
      specularIntensity: 0.04,
      innerGlow: 0.06,
    );
  }

  factory LiquidGlassConfig.modal() {
    return const LiquidGlassConfig(
      distortionScale: 16,
      blurAmount: 18,
      tintColor: Color(0xFFFFFFFF),
      tintOpacity: 0.20,
      borderOpacity: 0.26,
      specularIntensity: 0.06,
      innerGlow: 0.08,
    );
  }

  LiquidGlassConfig copyWith({
    double? distortionScale,
    double? blurAmount,
    Color? tintColor,
    double? tintOpacity,
    double? borderOpacity,
    double? specularIntensity,
    double? innerGlow,
  }) {
    return LiquidGlassConfig(
      distortionScale: distortionScale ?? this.distortionScale,
      blurAmount: blurAmount ?? this.blurAmount,
      tintColor: tintColor ?? this.tintColor,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      specularIntensity: specularIntensity ?? this.specularIntensity,
      innerGlow: innerGlow ?? this.innerGlow,
    );
  }
}

class LiquidGlassTheme extends InheritedWidget {
  const LiquidGlassTheme({
    super.key,
    required this.config,
    required super.child,
  });

  final LiquidGlassConfig config;

  static LiquidGlassConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>();
    assert(scope != null, 'LiquidGlassTheme not found in context');
    return scope!.config;
  }

  static LiquidGlassConfig? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<LiquidGlassTheme>()?.config;
  }

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) {
    return config.distortionScale != oldWidget.config.distortionScale ||
        config.blurAmount != oldWidget.config.blurAmount ||
        config.tintColor != oldWidget.config.tintColor ||
        config.tintOpacity != oldWidget.config.tintOpacity ||
        config.borderOpacity != oldWidget.config.borderOpacity;
  }
}
