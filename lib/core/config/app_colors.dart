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
}
