import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uygulamanın renkleri ve modern tema ayarları.
class AppColors {
  static const navy = Color(0xFF1B2A41);
  static const navyDeep = Color(0xFF0F1A2B);
  static const navyLight = Color(0xFF2E4A72);
  static const gold = Color(0xFFD4A537);
  static const goldLight = Color(0xFFF0C864);

  /// Kart avatarları için başlığın ilk harfine göre değişen gradyanlar.
  static const avatarGradients = [
    [Color(0xFF4A6FA5), Color(0xFF233A5E)],
    [Color(0xFFD4A537), Color(0xFFB07C1C)],
    [Color(0xFF3A7BD5), Color(0xFF2A4F9E)],
    [Color(0xFF11998E), Color(0xFF0B6E66)],
    [Color(0xFF8E54E9), Color(0xFF5B2FB0)],
    [Color(0xFFE5576C), Color(0xFFB3354A)],
  ];
}

class AppTheme {
  static ThemeData build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: b,
      primary: dark ? null : AppColors.navy,
      secondary: AppColors.gold,
      surface: dark ? const Color(0xFF0E1522) : const Color(0xFFF3F5F9),
    );
    final radius = BorderRadius.circular(18);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Kenardan kenara: şeffaf durum ve gezinme çubuğu.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF182133) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? AppColors.gold : AppColors.navy,
          foregroundColor: dark ? AppColors.navyDeep : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dark ? AppColors.gold : AppColors.navy,
        foregroundColor: dark ? AppColors.navyDeep : Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Kartlar için üç boyutlu görünüm veren katmanlı gölge.
  static List<BoxShadow> cardShadow(
    BuildContext context, {
    bool pressed = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final k = pressed ? 0.5 : 1.0;
    return [
      BoxShadow(
        color: (dark ? Colors.black : AppColors.navy).withValues(
          alpha: (dark ? 0.45 : 0.14) * k,
        ),
        blurRadius: 20 * k,
        offset: Offset(0, 8 * k),
      ),
      BoxShadow(
        color: (dark ? Colors.black : AppColors.navy).withValues(
          alpha: (dark ? 0.30 : 0.06) * k,
        ),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF172033)
      : Colors.white;
}
