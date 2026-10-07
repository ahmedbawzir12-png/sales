import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../cash/domain/entities/cash_flow_direction.dart';
import '../../../cash/domain/entities/cash_transaction.dart';
import '../../../cash/domain/entities/cash_transaction_type.dart';
import '../../../cash/data/repositories/cashbox_repository_impl.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';

/// تطبيق مستودع المصروفات التشغيلية
class ExpensesRepositoryImpl implements ExpensesRepository {
  final DatabaseService _dbService;
  final CashboxRepository _cashboxRepo;

  ExpensesRepositoryImpl({
    DatabaseService? dbService,
    CashboxRepository? cashboxRepo,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _cashboxRepo = cashboxRepo ??
            CashboxRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance);

  @override
  Future<List<Expense>> getExpenses({
    DateTime? from,
    DateTime? to,
    String? category,
  }) async {
    try {
      final db = await _dbService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (from != null) {
        whereClauses.add('expense_date >= ?');
        whereArgs.add(from.toIso8601String());
      }
      if (to != null) {
        whereClauses.add('expense_date <= ?');
        whereArgs.add(to.toIso8601String());
      }
      if (category != null && category.trim().isNotEmpty) {
        whereClauses.add('category_name = ?');
        whereArgs.add(category.trim());
      }

      final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final rows = await db.query(
        DatabaseConstants.tableExpenses,
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'expense_date DESC, id DESC',
      );

      return rows.map((r) => ExpenseModel.fromMap(r).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة المصروفات', e);
    }
  }

  @override
  Future<Expense> createExpense(Expense expense) async {
    if (expense.amount <= 0) {
      throw ValidationException('مبلغ المصروف يجب أن يكون أكبر من الصفر');
    }
    if (expense.categoryName.trim().isEmpty) {
      throw ValidationException('يرجى تحديد تصنيف المصروف');
    }
    if (expense.description.trim().isEmpty) {
      throw ValidationException('يرجى كتابة وصف أو بيان المصروف');
    }

    try {
      final db = await _dbService.database;

      return await db.transaction((txn) async {
        final now = DateTime.now();

        // 1. تسجيل المصروف في جدول المصروفات
        final model = ExpenseModel(
          id: 0,
          categoryName: expense.categoryName.trim(),
          amount: expense.amount,
          expenseDate: expense.expenseDate.toIso8601String(),
          description: expense.description.trim(),
          notes: expense.notes?.trim().isEmpty ?? true ? null : expense.notes?.trim(),
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
        );

        final expenseId = await txn.insert(
          DatabaseConstants.tableExpenses,
          model.toMap(),
        );

        // 2. صرف المبلغ نقدياً من الصندوق بشكل Atomic
        // في حال كان رصيد الصندوق غير كافٍ سيتم رمي استثناء وتراجع العملية تلقائياً (Rollback)
        await _cashboxRepo.recordCashTransactionWithExecutor(
          txn,
          CashTransaction(
            id: 0,
            type: CashTransactionType.expense,
            direction: CashFlowDirection.cashOut,
            amount: expense.amount,
            transactionDate: expense.expenseDate,
            referenceType: 'expense',
            referenceId: expenseId,
            description: 'مصروف: ${expense.categoryName} - ${expense.description}',
            notes: expense.notes,
            createdAt: now,
          ),
        );

        final saved = expense.copyWith(
          id: expenseId,
          createdAt: now,
          updatedAt: now,
        );

        AppDataNotifier.instance.notifyExpensesChanged(saved);

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل المصروف وصرفه من الصندوق', e);
    }
  }

  @override
  Future<int> getTodayExpensesTotal() async {
    try {
      final db = await _dbService.database;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final results = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM ${DatabaseConstants.tableExpenses}
        WHERE expense_date >= ? AND expense_date <= ?
      ''', [todayStart, todayEnd]);

      return (results.first['total'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب إجمالي مصروفات اليوم', e);
    }
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        DatabaseConstants.tableExpenseCategories,
        where: 'is_active = 1',
        orderBy: 'id ASC',
      );
      return rows.map((r) => ExpenseCategoryModel.fromMap(r).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تصنيفات المصروفات', e);
    }
  }

  @override
  Future<ExpenseCategory> createCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('يرجى إدخال اسم تصنيف المصروف');
    }

    try {
      final db = await _dbService.database;
      final now = DateTime.now().toIso8601String();

      final existing = await db.query(
        DatabaseConstants.tableExpenseCategories,
        where: 'name = ?',
        whereArgs: [trimmed],
      );

      if (existing.isNotEmpty) {
        throw ValidationException('تصنيف المصروف ($trimmed) موجود مسبقاً');
      }

      final id = await db.insert(
        DatabaseConstants.tableExpenseCategories,
        {
          'name': trimmed,
          'is_active': 1,
          'created_at': now,
        },
      );

      return ExpenseCategory(
        id: id,
        name: trimmed,
        isActive: true,
        createdAt: DateTime.parse(now),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء تصنيف مصروف جديد', e);
    }
  }
}
