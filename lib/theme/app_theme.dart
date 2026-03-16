import 'package:flutter/material.dart';

/// App theme with RFTag branding.
///
/// Uses dark mode for better demo presentation.
class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color accent = Color(0xFF00BCD4);
  static const Color surface = Color(0xFF1E1E2E);
  static const Color surfaceVariant = Color(0xFF2A2A3E);
  static const Color background = Color(0xFF121218);
  static const Color cardBackground = Color(0xFF1A1A24);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Text colors
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF616161);

  // Terminal colors
  static const Color terminalBg = Color(0xFF0D0D14);
  static const Color terminalTx = Color(0xFF64B5F6);
  static const Color terminalRx = Color(0xFF81C784);
  static const Color terminalError = Color(0xFFEF5350);
  static const Color terminalInfo = Color(0xFFB0BEC5);

  /// Get the dark theme.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceVariant, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceVariant),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 24),
      dividerTheme: const DividerThemeData(color: surfaceVariant, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        labelStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceVariant,
      ),
    );
  }

  /// Get the light theme (optional).
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
    );
  }
}
