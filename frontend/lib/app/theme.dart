import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color.fromRGBO(201, 202, 255, 1);
  static const Color primary = Color.fromARGB(255, 4, 0, 216);
  static const Color accent = Color.fromRGBO(184, 185, 255, 1);
  static const Color darkTurquoise = Color.fromARGB(255, 255, 173, 214);
  static const Color textPrimary = Color.fromRGBO(0, 28, 61, 1);
  static const Color textSecondary = Color.fromRGBO(2, 0, 90, 1);
  // إضافة التدرج اللوني  Color.fromARGB(255, 255, 173, 214);
  static Gradient get primaryGradient {
    return const LinearGradient(
      colors: [primary, darkTurquoise],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  // يمكنك إضافة تدرجات أخرى إذا احتجت
  static Gradient get accentGradient {
    return const LinearGradient(
      colors: [accent, Color(0xFFA0FFD0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
      ),
      colorScheme: const ColorScheme.light(primary: primary, secondary: accent),

      // إعدادات إضافية للغة العربية
      inputDecorationTheme: InputDecorationTheme(
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      ),
    );
  }

  static BoxDecoration get glassCard {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get gradientButton {
    return BoxDecoration(
      gradient: primaryGradient, // استخدام التدرج الجديد هنا
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: primary.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
