import 'package:flutter/material.dart';

import '../../models/enums.dart';

// Monochrome palette with iOS-tier depth.
// Surfaces use elevation via subtle transparency rather than borders.
// Blur and shadow are the primary depth cues, not outlines.
abstract class AppColors {
  // -- Backgrounds --
  static const Color background = Color(0xFF000000);
  static const Color surfaceSubtle = Color(0xFF111113);   // barely-there dark
  static const Color surface = Color(0xFF1C1C1E);        // iOS system grey 6
  static const Color surfaceLight = Color(0xFF2C2C2E);   // iOS system grey 5
  static const Color surfaceElevated = Color(0xFF3A3A3C); // iOS system grey 4

  // -- Accent --
  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentDim = Color(0xFF8E8E93);       // iOS system grey
  static const Color onAccent = Color(0xFF000000);

  // -- Text --
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);   // iOS secondary label
  static const Color textTertiary = Color(0xFF48484A);    // iOS tertiary label
  static const Color textDisabled = Color(0xFF3A3A3C);

  // -- SLA Status --
  // These are the only colour in the entire app.
  static const Color onTrack = Color(0xFF30D158);   // iOS system green
  static const Color atRisk = Color(0xFFFFD60A);    // iOS system yellow
  static const Color overdue = Color(0xFFFF453A);   // iOS system red
  static const Color completed = Color(0xFF8E8E93); // system grey

  // -- Glass / Blur --
  static const Color glass = Color(0x33FFFFFF);       // white at 20% for frosted panels
  static const Color glassStroke = Color(0x1AFFFFFF); // white at 10% for glass borders
  static const Color scrim = Color(0x99000000);       // 60% black overlay

  // -- Utility --
  static const Color divider = Color(0xFF38383A);     // iOS separator
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static Color statusColor(SLAStatus status) {
    switch (status) {
      case SLAStatus.onTrack:
        return onTrack;
      case SLAStatus.atRisk:
        return atRisk;
      case SLAStatus.overdue:
        return overdue;
      case SLAStatus.completed:
        return completed;
    }
  }

  static Color priorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return overdue;
      case Priority.medium:
        return atRisk;
      case Priority.low:
        return onTrack;
    }
  }
}
