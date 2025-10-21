// lib/app/localization.dart
import 'package:flutter/material.dart';

class AppLocalization {
  static const Locale arabicLocale = Locale('ar', 'SA');

  static bool isRTL(Locale locale) {
    return locale.languageCode == 'ar';
  }

  // دالة مساعدة لتطبيق الـ RTL تلقائياً
  static TextDirection get textDirection {
    return TextDirection.rtl;
  }

  static TextAlign get textAlign {
    return TextAlign.right;
  }
}
