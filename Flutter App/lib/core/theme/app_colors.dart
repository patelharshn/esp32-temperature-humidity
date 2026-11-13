import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (IoT Tech Blue & Emerald Accents)
  static const Color primary = Color(0xFF0F52BA); // Sapphire Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF0A3678);

  static const Color secondary = Color(0xFF06B6D4); // Cyan Accent
  static const Color secondaryLight = Color(0xFF22D3EE);

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF047857);

  static const Color error = Color(0xFFEF4444); // Crimson Red
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0xFFFEF3C7);

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoBg = Color(0xFFDBEAFE);

  // Lock / Gate Barrier Specific
  static const Color locked = Color(0xFFEF4444); // Red: Secured & Closed
  static const Color unlocked = Color(0xFF10B981); // Green: Barrier Open
  static const Color gateClosed = Color(0xFFEF4444);
  static const Color gateOpen = Color(0xFF10B981);

  // Neutral Colors (Dark Theme)
  static const Color darkBackground = Color(0xFF0B0F19); // Deep OLED Navy
  static const Color darkSurface = Color(0xFF161F30);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Neutral Colors (Light Theme)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Sensor Specific
  static const Color tempHot = Color(0xFFF97316);
  static const Color tempCool = Color(0xFF06B6D4);
  static const Color humidity = Color(0xFF3B82F6);
}
