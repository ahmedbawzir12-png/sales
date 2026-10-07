/// ملخص ومؤشرات الصندوق المالي
class CashboxSummary {
  /// الرصيد الإجمالي الفعلي الحالي للصندوق (محسوب من مجموع الحركات)
  final int currentBalance;

  /// الرصيد الافتتاحي للصندوق
  final int openingBalance;

  /// إجمالي الأموال الداخلة اليوم
  final int todayCashIn;

  /// إجمالي الأموال الخارجة اليوم
  final int todayCashOut;

  /// صافي حركة اليوم (الداخل - الخارج)
  final int todayNet;

  /// إجمالي عدد الحركات المسجلة
  final int totalTransactionsCount;

  const CashboxSummary({
    required this.currentBalance,
    required this.openingBalance,
    required this.todayCashIn,
    required this.todayCashOut,
    required this.todayNet,
    required this.totalTransactionsCount,
  });

  @override
  String toString() =>
      'CashboxSummary(balance: $currentBalance, opening: $openingBalance, inToday: $todayCashIn, outToday: $todayCashOut, netToday: $todayNet)';
}
