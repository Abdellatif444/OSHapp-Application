import 'package:flutter/material.dart';
import 'package:oshapp/shared/config/app_theme.dart';

/// Centralized mapping between appointment status UI categories and colors.
/// Keeps UI styling concerns out of the data model and ensures consistency.
class StatusStyle {
  /// Returns the color associated with a given status UI category.
  /// Recognized categories: REQUESTED, PROPOSED, CONFIRMED, CANCELLED, COMPLETED.
  /// Falls back to a neutral text color for unknown categories.
  static Color colorFor(String? category) {
    switch ((category ?? 'UNKNOWN').toUpperCase()) {
      case 'REQUESTED':
        return AppTheme.warningColor; // Orange
      case 'PROPOSED':
        return AppTheme.infoColor; // Blue
      case 'CONFIRMED':
        return AppTheme.successColor; // Green
      case 'CANCELLED':
        return AppTheme.errorColor; // Red
      case 'COMPLETED':
        // Use secondaryColor (corporate) to represent completion/finality
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textPrimary; // Neutral/dark
    }
  }
}
