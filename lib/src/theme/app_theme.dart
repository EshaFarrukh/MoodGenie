import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

// ─── Design Tokens ───────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — Primary (Oceanic Blue)
  static const Color primary       = Color(0xFF0066CC); // Vibrant Blue
  static const Color primaryDeep   = Color(0xFF003B73); // Deep Navy
  static const Color primaryMid    = Color(0xFF3D8BFD); // Mid Blue
  static const Color primaryLight  = Color(0xFFEAF6FB); // Light Cyan Background
  static const Color primarySoft   = Color(0xFFBDE4F4); // Soft Cyan Gradient
  static const Color primaryFaint  = Color(0xFFF1F8FE); // Faint Blue Cards

  // Brand — Accent
  static const Color accentCyan     = Color(0xFF00B4D8); // Bright Cyan Accent
  static const Color accentSoft     = Color(0xFF48CAE4); // Secondary Soft Cyan
  static const Color accentBright   = Color(0xFF90E0EF); // Very Light Cyan

  // Text
  static const Color headingDark  = Color(0xFF002B5B); // Very Dark Navy for Text
  static const Color textPrimary  = Color(0xFF334155); // Slate 700
  static const Color textSecondary= Color(0xFF64748B); // Slate 500
  static const Color bodyMuted    = Color(0xFF475569); // Slate 600
  static const Color captionLight = Color(0xFF94A3B8); // Slate 400

  // Surface / Cards
  static const Color cardWhite    = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceWarm  = Color(0xFFF1F5F9);

  // Semantic
  static const Color success      = Color(0xFF10B981);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorSoft    = Color(0xFFF87171);
  static const Color warning      = Color(0xFFF59E0B);

  // Nav
  static const Color pillCyan     = Color(0xFFE0F2FE); // Light Sky Blue for pills
  static const Color navUnselected= Color(0xFF94A3B8);
}

class AppRadius {
  AppRadius._();
  static const double s  = 14;
  static const double m  = 20;
  static const double l  = 24;
  static const double xl = 28;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> card({Color? color}) => [
        BoxShadow(
          color: (color ?? AppColors.primary).withOpacity(0.12),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];
}

// ─── Theme ───────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData.light();

    // Safe text theme with fallback
    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );
    } catch (e) {
      textTheme = base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );
    }

    TextStyle? appBarTitleStyle;
    try {
      appBarTitleStyle = GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );
    } catch (e) {
      appBarTitleStyle = const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );
    }

    TextStyle? buttonTextStyle;
    try {
      buttonTextStyle = GoogleFonts.poppins(fontWeight: FontWeight.w700);
    } catch (e) {
      buttonTextStyle = const TextStyle(fontWeight: FontWeight.w700);
    }

    return base.copyWith(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accentCyan,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: appBarTitleStyle,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accentCyan,
        unselectedItemColor: AppColors.navUnselected,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: buttonTextStyle,
        ),
      ),
    );
  }
}
