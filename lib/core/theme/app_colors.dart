import 'package:flutter/material.dart';

/// App color palette - matching basidekick.com design
class AppColors {
  AppColors._();

  // Primary brand colors - Amber/Gold accent
  static const Color primary = Color(0xFFF5A623); // Amber gold
  static const Color primaryLight = Color(0xFFFFBF47);
  static const Color primaryDark = Color(0xFFD4890D);

  // Secondary colors
  static const Color secondary = Color(0xFF22C55E); // Green for status
  static const Color secondaryLight = Color(0xFF4ADE80);
  static const Color secondaryDark = Color(0xFF16A34A);

  // Neutral colors - Dark theme primary
  static const Color background = Color(0xFF0A0A0A); // Near black
  static const Color surface = Color(0xFF141414); // Dark gray cards
  static const Color surfaceVariant = Color(0xFF1F1F1F); // Slightly lighter

  // Border colors
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF3A3A3A);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFF888888); // Medium gray
  static const Color textTertiary = Color(0xFF666666); // Darker gray

  // Status colors
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF5A623); // Amber (matches primary)
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Equipment/Point status colors
  static const Color online = Color(0xFF22C55E); // Green
  static const Color offline = Color(0xFF666666); // Gray
  static const Color fault = Color(0xFFEF4444); // Red

  // Role colors
  static const Color adminBadge = Color(0xFFF5A623); // Amber for admin
  static const Color techBadge = Color(0xFF3B82F6); // Blue for tech

  // Legacy light theme colors (for compatibility)
  static const Color backgroundDark = background;
  static const Color surfaceDark = surface;
  static const Color surfaceVariantDark = surfaceVariant;
  static const Color textPrimaryDark = textPrimary;
  static const Color textSecondaryDark = textSecondary;
}
