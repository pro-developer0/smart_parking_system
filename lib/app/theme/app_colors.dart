import 'package:flutter/material.dart';

/// Central color palette. Kept minimal and semantic so the whole app reads
/// from one source of truth.
abstract class AppColors {
  // Brand
  static const Color primary = Color(0xFF4F46E5); // indigo
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color accent = Color(0xFF06B6D4); // cyan

  // Slot status
  static const Color available = Color(0xFF10B981); // emerald
  static const Color occupied = Color(0xFFEF4444); // red
  static const Color mine = Color(0xFF4F46E5); // indigo (same as brand)

  // Slot conditions set by the admin
  static const Color construction = Color(0xFFF59E0B); // amber
  static const Color maintenance = Color(0xFF0EA5E9); // sky blue
  static const Color reserved = Color(0xFFEC4899); // pink
  static const Color closed = Color(0xFF64748B); // slate grey

  // Light neutrals
  static const Color lightBg = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE6E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightMuted = Color(0xFF64748B);

  // Dark neutrals
  static const Color darkBg = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF151B2B);
  static const Color darkBorder = Color(0xFF26304A);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkMuted = Color(0xFF94A3B8);
}
