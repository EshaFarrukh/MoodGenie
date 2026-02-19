import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ───────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — Primary
  static const Color purple       = Color(0xFF8B7FD8);
  static const Color purpleDeep   = Color(0xFF6B5CFF);
  static const Color purpleMid    = Color(0xFF7B6FD8);
  static const Color purpleLight  = Color(0xFFF4EEFF);
  static const Color purpleSoft   = Color(0xFF9B8FD8);
  static const Color purpleFaint  = Color(0xFFE5DEFF);

  // Brand — Accent
  static const Color accentOrange   = Color(0xFFFF9966);
  static const Color accentWarm     = Color(0xFFFF8E58);
  static const Color accentPeach    = Color(0xFFFFB06A);

  // Text
  static const Color headingDark  = Color(0xFF2D2545);
  static const Color textPrimary  = Color(0xFF374151);
  static const Color textSecondary= Color(0xFF6B7280);
  static const Color bodyMuted    = Color(0xFF6D6689);
  static const Color captionLight = Color(0xFF8A7F92);

  // Surface / Cards
  static const Color cardWhite    = Color(0xFFFFFFFE);
  static const Color surfaceLight = Color(0xFFFDF5FF);
  static const Color surfaceWarm  = Color(0xFFFFF5EA);

  // Semantic
  static const Color success      = Color(0xFF4CAF50);
  static const Color error        = Color(0xFFFF5252);
  static const Color errorSoft    = Color(0xFFFF6B6B);
  static const Color warning      = Color(0xFFFFA726);

  // Nav
  static const Color pillLilac    = Color(0xFFF2EEFF);
  static const Color navUnselected= Color(0xFFB0B0C3);
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
          color: (color ?? AppColors.purple).withOpacity(0.12),
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
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        secondary: AppColors.accentOrange,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: appBarTitleStyle,
        iconTheme: const IconThemeData(color: AppColors.purple),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accentOrange,
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
