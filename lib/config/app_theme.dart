import 'package:flutter/material.dart';

/// 应用颜色常量
class AppColors {
  static const Color primary = Color(0xFFFF8C00);
  static const Color primaryLight = Color(0xFFFFA500);
  static const Color primaryDark = Color(0xFFE67E00);
  static const Color accent = Color(0xFFFFB347);
  static const Color gradientStart = Color(0xFFFF8C00);
  static const Color gradientEnd = Color(0xFFFFA500);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color tagBackground = Color(0xFFFFF3E0);
  static const Color tagText = Color(0xFFFF8C00);
  static const Color starColor = Color(0xFFFFD700);
  static const Color vipGold = Color(0xFFDAA520);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFFF9A3E), Color(0xFFFFC078)],
    begin: Alignment.topCenter,
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
        centerTitle: false,
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
