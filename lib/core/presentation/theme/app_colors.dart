import 'package:flutter/material.dart';

/// لوحة الألوان المركزية للنظام المحاسبي والإداري في طبقة العرض
class AppColors {
  AppColors._();

  // الألوان الأساسية
  static const Color primary = Color(0xFF1E3A8A); // كحلي رصين وموثوق
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimaryContainer = Color(0xFF1E3A8A);

  // الألوان الثانوية (هوية المفروشات الخشبية الراقية)
  static const Color secondary = Color(0xFF92400E); // كهرماني خشبي دافئ
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFFEF3C7);
  static const Color onSecondaryContainer = Color(0xFF78350F);

  // ألوان الخلفيات والأسطح
  static const Color background = Color(0xFFF8FAFC); // خلفية عمل مريحة للعين
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color surfaceHighlight = Color(0xFFE2E8F0);

  // ألوان النصوص
  static const Color textPrimary = Color(0xFF0F172A); // نص رئيسي عالي التباين
  static const Color textSecondary = Color(0xFF475569); // نصوص ثانوية
  static const Color textMuted = Color(0xFF94A3B8); // نصوص توضيحية خافتة
  static const Color textDisabled = Color(0xFFCBD5E1);

  // الحدود والفواصل
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color divider = Color(0xFFF1F5F9);

  // دلالات الحالات المالية
  static const Color success = Color(0xFF059669); // للمقبوضات والأرباح
  static const Color onSuccess = Colors.white;
  static const Color successContainer = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFD97706); // للتنبيهات والذمم
  static const Color onWarning = Colors.white;
  static const Color warningContainer = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFDC2626); // للمدفوعات والأخطاء
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF0284C7);
}
