import 'date_range.dart';

/// سطر توزيع المصروفات حسب التصنيف
class ExpenseCategoryReportRow {
  final String categoryName;
  final int amount;
  final double percentage;

  const ExpenseCategoryReportRow({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

/// سطر عملية المصروف
class ExpenseReportRow {
  final int id;
  final String categoryName;
  final int amount;
  final DateTime expenseDate;
  final String description;
  final String? notes;

  const ExpenseReportRow({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.expenseDate,
    required this.description,
    this.notes,
  });
}

/// بيانات تقرير المصروفات للفترة المحددة
class ExpensesReportData {
  final DateRange dateRange;
  final int totalExpenses;
  final List<ExpenseCategoryReportRow> categoryBreakdown;
  final List<ExpenseReportRow> expenses;

  const ExpensesReportData({
    required this.dateRange,
    required this.totalExpenses,
    required this.categoryBreakdown,
    required this.expenses,
  });

  factory ExpensesReportData.empty(DateRange range) {
    return ExpensesReportData(
      dateRange: range,
      totalExpenses: 0,
      categoryBreakdown: const [],
      expenses: const [],
    );
  }
}
