import '../constants/app_constants.dart';

/// أدوات تنسيق القيم المالية والتواريخ في طبقة العرض
class AppFormatters {
  AppFormatters._();

  /// تنسيق المبالغ المالية بطريقة مقروءة ومرتبة مع منزلتين عشريتين
  static String currency(num amount, {String currency = AppConstants.defaultCurrency}) {
    final isNegative = amount < 0;
    final absoluteAmount = amount.abs();

    final parts = absoluteAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    final formattedNumber = '${buffer.toString()}.$decimalPart';
    final result = '$formattedNumber $currency';
    return isNegative ? '- $result' : result;
  }

  /// تنسيق التاريخ للعرض: YYYY/MM/DD
  static String date(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  /// تنسيق التاريخ والوقت للعرض: YYYY/MM/DD HH:MM
  static String dateTime(DateTime dateTime) {
    final d = date(dateTime);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$d $hour:$minute';
  }
}
