import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData getDarkTheme(String languageCode) {
    final isArabic = languageCode == 'ar';
    final baseTextTheme =
        isArabic ? GoogleFonts.cairoTextTheme() : GoogleFonts.latoTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.primaryDark,
      primaryColor: AppColors.brandPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandTeal,
        surface: AppColors.surfaceCard,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.accentRed,
      ),
      // خلفية Scaffold الافتراضية داكنة، لذا النصوص/الأيقونات الافتراضية بلا
      // لون محدَّد (مثل ListTile) يجب أن تكون فاتحة تلقائياً بدل الأسود.
      textTheme: baseTextTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            displayLarge: baseTextTheme.displayLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            headlineLarge: baseTextTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            titleLarge:
                baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            bodyLarge:
                baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            bodyMedium: baseTextTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.normal),
          ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dialogTheme: const DialogTheme(
        backgroundColor: AppColors.surfaceCard,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
      ),
    );
  }
}
