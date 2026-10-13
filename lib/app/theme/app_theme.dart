import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fineer brand color tokens
class FC {
  // Brand primary
  static const blue = Color(0xFF0078D7);
  static const blueDark = Color(0xFF0052A3);
  static const yellow = Color(0xFFFFF200);

  // Light palette
  static const bgLight = Colors.white;
  static const cardLight = Colors.white;
  static const borderLight = Color(0xFFD6E8F7);
  static const textLight = Color(0xFF0D1B35); // text primary   (was tp_Light)
  static const textSecLight =
      Color(0xFF4A6080); // text secondary (was ts_Light)
  static const textTerLight =
      Color(0xFF8BA3C0); // text tertiary  (was tt_Light)
  static const mutedLight = Color(0xFFF0F6FF);

  // Dark palette
  static const bgDark = Color(0xFF060D1F);
  static const cardDark = Color(0xFF0D1729);
  static const card2Dark = Color(0xFF132035);
  static const borderDark = Color(0xFF1A2E48);
  static const textDark = Color(0xFFF0F6FF); // text primary   (was tp_Dark)
  static const textSecDark = Color(0xFF7A9EBF); // text secondary (was ts_Dark)
  static const textTerDark = Color(0xFF3D5A7A); // text tertiary  (was tt_Dark)

  // Semantic
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  static ThemeData _build(bool dark) {
    final bg = dark ? FC.bgDark : FC.bgLight;
    final card = dark ? FC.cardDark : FC.cardLight;
    final border = dark ? FC.borderDark : FC.borderLight;
    final tp = dark ? FC.textDark : FC.textLight;
    final ts = dark ? FC.textSecDark : FC.textSecLight;
    final tt = dark ? FC.textTerDark : FC.textTerLight;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: FC.blue,
        onPrimary: Colors.white,
        secondary: FC.yellow,
        onSecondary: FC.blue,
        error: FC.error,
        onError: Colors.white,
        surface: card,
        onSurface: tp,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: tp,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: tp,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: ts),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? FC.card2Dark : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: FC.blue, width: 1.5)),
        hintStyle: TextStyle(color: tt, fontSize: 14),
        labelStyle: TextStyle(color: ts),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FC.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FC.blue,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? FC.card2Dark : Colors.white,
        contentTextStyle: TextStyle(color: tp, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
    );
  }
}
