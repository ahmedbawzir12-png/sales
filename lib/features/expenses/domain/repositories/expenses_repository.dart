import '../entities/expense.dart';
import '../entities/expense_category.dart';

/// واجهة مستودع المصروفات التشغيلية
abstract class ExpensesRepository {
  /// استرجاع قائمة المصروفات مع الفلترة الاختيارية
  Future<List<Expense>> getExpenses({
    DateTime? from,
    DateTime? to,
    String? category,
  });

  /// تسجيل مصروف تشغيلي جديد وصرفه نقدياً من الصندوق بشكل Atomic
  Future<Expense> createExpense(Expense expense);

  /// إجمالي مصروفات اليوم
  Future<int> getTodayExpensesTotal();

  /// استرجاع تصنيفات المصروفات النشطة
  Future<List<ExpenseCategory>> getCategories();

  /// إضافة تصنيف مصروفات جديد
  Future<ExpenseCategory> createCategory(String name);
}
