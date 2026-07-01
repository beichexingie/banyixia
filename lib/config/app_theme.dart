import 'package:flutter/material.dart';

/// 应用颜色常量
class AppColors {
  static const Color primary = Color(0xFFC8FF28);
  static const Color primaryLight = Color(0xFFE7FF9B);
  static const Color primaryDark = Color(0xFF9FD900);
  static const Color accent = Color(0xFFFF6938);
  static const Color gradientStart = Color(0xFFC8FF28);
  static const Color gradientEnd = Color(0xFFE8FFBE);
  static const Color background = Color(0xFFF4F5F7);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF555555);
  static const Color textHint = Color(0xFFA0A0A8);
  static const Color divider = Color(0xFFEAEAF0);
  static const Color tagBackground = Color(0xFFF0F1F5);
  static const Color tagText = Color(0xFF171717);
  static const Color starColor = Color(0xFFFFA33C);
  static const Color vipGold = Color(0xFFF5B34F);
  static const Color darkSurface = Color(0xFF171717);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFC8FF28), Color(0xFFE8FFBE), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomCenter,
  );
}

/// 应用字体样式
class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textHint,
  );

  static const TextStyle tag = TextStyle(
    fontSize: 11,
    color: AppColors.tagText,
    fontWeight: FontWeight.w500,
  );
}

/// 应用主题
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.cardBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        indicatorColor: AppColors.primary,
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 15),
      ),
    );
  }
}
