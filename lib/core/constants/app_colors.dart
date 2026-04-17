import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette
  static const Color primary = Color(0xFF6C3CE1);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color primaryDark = Color(0xFF4C1D95);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Accent gradient endpoints
  static const Color accentA = Color(0xFF818CF8);
  static const Color accentB = Color(0xFFC084FC);

  // Light mode
  static const Color lightBackground = Color(0xFFF5F3FF);
  static const Color lightSurface = Color(0xFFEDE9FE);
  static const Color lightGlassSurface = Color(0xFFFFFFFF);
  static const Color lightGlassElevated = Color(0xFFFAF5FF);
  static const Color lightGlassModal = Color(0xFFFFFFFF);

  // Dark mode
  static const Color darkBackground = Color(0xFF0C0A1D);
  static const Color darkSurface = Color(0xFF13102B);
  static const Color darkGlassSurface = Color(0xFF1E1940);
  static const Color darkGlassElevated = Color(0xFF261F52);
  static const Color darkGlassModal = Color(0xFF2D2460);

  // Gradient presets
  static const lightGradient = [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFF0E6FF)];
  static const darkGradient = [Color(0xFF0C0A1D), Color(0xFF13102B), Color(0xFF1A1145)];

  static const shimmerGradient = [
    Color(0x00FFFFFF),
    Color(0x33FFFFFF),
    Color(0x00FFFFFF),
  ];
}
