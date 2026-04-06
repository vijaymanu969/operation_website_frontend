import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF1A1A2E);
  static const accent = Color(0xFFE94560);

  // Sidebar & nav
  static const sidebarBg = primary;
  static const navItemText = Colors.white70;
  static const navItemHover = Colors.white10;

  // Status colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF42A5F5);

  // Task priority
  static const priorityHigh = Color(0xFFEF5350);
  static const priorityMedium = Color(0xFFFFA726);
  static const priorityLow = Color(0xFF42A5F5);

  // Task health
  static const healthActive = Color(0xFF4CAF50);
  static const healthAtRisk = Color(0xFFFFA726);
  static const healthStagnant = Color(0xFFEF5350);
  static const healthDead = Color(0xFF9E9E9E);

  // Attendance
  static const present = Color(0xFF4CAF50);
  static const leave = Color(0xFFFFF3CD);
  static const absent = Color(0xFFFFEBEE);

  // ── User avatar colors (from backend ops_users.color) ─────────────────────
  // These match the backend's allowed color values.
  static const _userColorMap = <String, Color>{
    'gray':   Color(0xFF9CA3AF),
    'red':    Color(0xFFEF4444),
    'orange': Color(0xFFF59E0B),
    'yellow': Color(0xFFEAB308),
    'green':  Color(0xFF10B981),
    'blue':   Color(0xFF3B82F6),
    'purple': Color(0xFF8B5CF6),
    'pink':   Color(0xFFEC4899),
  };

  /// Map a backend color string to a Flutter Color.
  /// Falls back to gray for unknown values.
  static Color userColor(String? name) =>
      _userColorMap[name ?? 'gray'] ?? _userColorMap['gray']!;

  /// Keys available for color pickers (matches backend enum).
  static const userColorKeys = [
    'gray', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink',
  ];
}
