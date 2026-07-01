import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFB7FF1E);
  static const Color primaryDeep = Color(0xFF9AE300);
  static const Color primarySoft = Color(0xFFE9FFAF);
  static const Color primaryLight = primarySoft;
  static const Color primaryDark = primaryDeep;
  static const Color accent = Color(0xFFF1F9D7);
  static const Color gradientStart = primary;
  static const Color gradientEnd = primarySoft;
  static const Color background = Color(0xFFF5F5F0);
  static const Color cardBackground = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7F7F7);
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color textHint = Color(0xFFB4B4B4);
  static const Color divider = Color(0xFFEDEDED);
  static const Color tagBackground = Color(0xFFF5F8EA);
  static const Color tagText = Color(0xFF171717);
  static const Color starColor = Color(0xFFFFA24A);
  static const Color vipGold = Color(0xFFFFD36C);
  static const Color warning = Color(0xFFFF6E3C);
  static const Color success = Color(0xFF7DD321);
  static const Color dark = Color(0xFF232323);
  static const Color darkSurface = dark;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFDFFF90), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFF5FFE2), Color(0xFFC9FF42)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pageGlowGradient = LinearGradient(
    colors: [Color(0xFFF8FEEB), Color(0xFFDFFF78), Colors.white],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.22, 0.62],
  );
}

class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textHint,
    height: 1.35,
  );

  static const TextStyle tag = TextStyle(
    fontSize: 11,
    color: AppColors.tagText,
    fontWeight: FontWeight.w700,
  );
}

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
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textHint,
        indicatorColor: AppColors.primary,
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.dark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
