import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../domain/entities/cash_flow_direction.dart';
import '../../domain/entities/cash_transaction.dart';
import '../../domain/entities/cash_transaction_type.dart';
import '../../domain/entities/cashbox_summary.dart';
import '../../domain/repositories/cashbox_repository.dart';
import '../models/cash_transaction_model.dart';

/// تطبيق مستودع الصندوق في طبقة البيانات باستخدام SQLite
class CashboxRepositoryImpl implements CashboxRepository {
  final DatabaseService _dbService;

  CashboxRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<int> getCashBalance() async {
    try {
      final db = await _dbService.database;
      return await getCashBalanceWithExecutor(db);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب رصيد الصندوق الحالي', e);
    }
  }

  /// حساب الرصيد باستخدام منفذ معاملات محدد لدعم العمليات الذرية (Transactions)
  Future<int> getCashBalanceWithExecutor(DatabaseExecutor executor) async {
    final results = await executor.rawQuery('''
      SELECT COALESCE(
        SUM(
          CASE 
            WHEN direction = 'cashIn' THEN amount 
            WHEN direction = 'cashOut' THEN -amount 
            ELSE 0 
          END
        ), 
        0
      ) AS balance
      FROM ${DatabaseConstants.tableCashTransactions}
    ''');

    return (results.first['balance'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<CashboxSummary> getCashboxSummary({DateTime? from, DateTime? to}) async {
    try {
      final db = await _dbService.database;
      final currentBalance = await getCashBalanceWithExecutor(db);

      // 1. استخراج الرصيد الافتتاحي
      final openingRow = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS opening_total
        FROM ${DatabaseConstants.tableCashTransactions}
        WHERE transaction_type = ?
      ''', [CashTransactionType.openingBalance.name]);
      final openingBalance = (openingRow.first['opening_total'] as num?)?.toInt() ?? 0;

      // 2. حساب حركات اليوم
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final todayInRow = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS today_in
        FROM ${DatabaseConstants.tableCashTransactions}
        WHERE direction = 'cashIn' 
          AND transaction_type != ?
          AND transaction_date >= ? 
          AND transaction_date <= ?
      ''', [CashTransactionType.openingBalance.name, todayStart, todayEnd]);
      final todayCashIn = (todayInRow.first['today_in'] as num?)?.toInt() ?? 0;

      final todayOutRow = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS today_out
        FROM ${DatabaseConstants.tableCashTransactions}
        WHERE direction = 'cashOut' 
          AND transaction_date >= ? 
          AND transaction_date <= ?
      ''', [todayStart, todayEnd]);
      final todayCashOut = (todayOutRow.first['today_out'] as num?)?.toInt() ?? 0;

      // 3. إجمالي عدد الحركات
      final countRow = await db.rawQuery('''
        SELECT COUNT(*) AS total_count
        FROM ${DatabaseConstants.tableCashTransactions}
      ''');
      final totalCount = (countRow.first['total_count'] as num?)?.toInt() ?? 0;

      return CashboxSummary(
        currentBalance: currentBalance,
        openingBalance: openingBalance,
        todayCashIn: todayCashIn,
        todayCashOut: todayCashOut,
        todayNet: todayCashIn - todayCashOut,
        totalTransactionsCount: totalCount,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع ملخص بيانات الصندوق', e);
    }
  }

  @override
  Future<List<CashTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    CashFlowDirection? direction,
    CashTransactionType? type,
  }) async {
    try {
      final db = await _dbService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (from != null) {
        whereClauses.add('transaction_date >= ?');
        whereArgs.add(from.toIso8601String());
      }
      if (to != null) {
        whereClauses.add('transaction_date <= ?');
        whereArgs.add(to.toIso8601String());
      }
      if (direction != null) {
        whereClauses.add('direction = ?');
        whereArgs.add(direction.name);
      }
      if (type != null) {
        whereClauses.add('transaction_type = ?');
        whereArgs.add(type.name);
      }

      final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      // استرجاع كافة الحركات مرتبة زمنياً تصاعدياً أولاً لحساب الرصيد التراكمي بدقة
      final allRows = await db.query(
        DatabaseConstants.tableCashTransactions,
        orderBy: 'transaction_date ASC, id ASC',
      );

      // حساب الرصيد بعد كل حركة (Running Balance)
      int running = 0;
      final runningBalanceMap = <int, int>{};
      for (final row in allRows) {
        final id = row['id'] as int;
        final dir = row['direction'] as String;
        final amt = row['amount'] as int;
        if (dir == 'cashIn') {
          running += amt;
        } else {
          running -= amt;
        }
        runningBalanceMap[id] = running;
      }

      // استرجاع الحركات المفلترة مرتبة تنازلياً للعرض
      final filteredRows = await db.query(
        DatabaseConstants.tableCashTransactions,
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'transaction_date DESC, id DESC',
      );

      return filteredRows.map((row) {
        final id = row['id'] as int;
        final model = CashTransactionModel.fromMap(row);
        return model.toEntity(runningBalance: runningBalanceMap[id]);
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل حركات الصندوق', e);
    }
  }

  @override
  Future<bool> hasOpeningBalance() async {
    try {
      final db = await _dbService.database;
      final results = await db.rawQuery('''
        SELECT COUNT(*) AS count
        FROM ${DatabaseConstants.tableCashTransactions}
        WHERE transaction_type = ?
      ''', [CashTransactionType.openingBalance.name]);
      final count = (results.first['count'] as num?)?.toInt() ?? 0;
      return count > 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل فحص وجود الرصيد الافتتاحي للصندوق', e);
    }
  }

  @override
  Future<CashTransaction?> getOpeningBalance() async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        DatabaseConstants.tableCashTransactions,
        where: 'transaction_type = ?',
        whereArgs: [CashTransactionType.openingBalance.name],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return CashTransactionModel.fromMap(results.first).toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بيانات الرصيد الافتتاحي', e);
    }
  }

  @override
  Future<CashTransaction> setOpeningBalance(
    int amount, {
    DateTime? date,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ValidationException('مبلغ الرصيد الافتتاحي يجب أن يكون أكبر من الصفر');
    }

    try {
      final db = await _dbService.database;
      return await db.transaction((txn) async {
        // حماية من التكرار العشوائي للرصيد الافتتاحي
        final existing = await txn.rawQuery('''
          SELECT COUNT(*) AS count
          FROM ${DatabaseConstants.tableCashTransactions}
          WHERE transaction_type = ?
        ''', [CashTransactionType.openingBalance.name]);

        final count = (existing.first['count'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          throw ValidationException(
            'تم تسجيل الرصيد الافتتاحي للصندوق مسبقاً، ولا يمكن تسجيل رصيد افتتاحي آخر.',
          );
        }

        final now = DateTime.now();
        final txDate = date ?? now;

        final transaction = CashTransaction(
          id: 0,
          type: CashTransactionType.openingBalance,
          direction: CashFlowDirection.cashIn,
          amount: amount,
          transactionDate: txDate,
          description: 'الرصيد الافتتاحي الأولي للصندوق',
          notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
          createdAt: now,
        );

        return await recordCashTransactionWithExecutor(txn, transaction);
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعيين الرصيد الافتتاحي للصندوق', e);
    }
  }

  @override
  Future<CashTransaction> recordCashTransaction(CashTransaction transaction) async {
    try {
      final db = await _dbService.database;
      return await db.transaction((txn) async {
        return await recordCashTransactionWithExecutor(txn, transaction);
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل حركة الصندوق', e);
    }
  }

  @override
  Future<CashTransaction> recordCashTransactionWithExecutor(
    dynamic executor,
    CashTransaction transaction,
  ) async {
    final exec = executor as DatabaseExecutor;

    // 1. التحقق من صحة المبلغ
    if (transaction.amount <= 0) {
      throw ValidationException('مبلغ حركة الصندوق يجب أن يكون رقماً موجباً أكبر من الصفر');
    }

    // 2. التحقق ومنع تكرار الحركة للعمليات المرتبطة بمستندات
    if (transaction.referenceType != null && transaction.referenceId != null) {
      final existing = await exec.query(
        DatabaseConstants.tableCashTransactions,
        where: 'reference_type = ? AND reference_id = ? AND transaction_type = ?',
        whereArgs: [
          transaction.referenceType,
          transaction.referenceId,
          transaction.type.name,
        ],
      );
      if (existing.isNotEmpty) {
        throw ValidationException(
          'تم تسجيل حركة الصندوق لهذه العملية مسبقاً لمنع التكرار (مرجع: ${transaction.referenceType}#${transaction.referenceId})',
        );
      }
    }

    // 3. منع الرصيد السالب بشكل صارم داخل الـ Transaction
    if (transaction.direction == CashFlowDirection.cashOut) {
      final currentBalance = await getCashBalanceWithExecutor(exec);
      if (currentBalance < transaction.amount) {
        throw ValidationException(
          'رصيد الصندوق غير كافٍ لإتمام العملية (الرصيد المتاح: $currentBalance، المطلوب صرفه: ${transaction.amount}). لا يمكن أن يصبح رصيد الصندوق سالباً.',
        );
      }
    }

    // 4. إدراج الحركة
    final now = DateTime.now();
    final model = CashTransactionModel(
      id: 0,
      transactionType: transaction.type.name,
      direction: transaction.direction.name,
      amount: transaction.amount,
      transactionDate: transaction.transactionDate.toIso8601String(),
      referenceType: transaction.referenceType,
      referenceId: transaction.referenceId,
      description: transaction.description,
      notes: transaction.notes?.trim().isEmpty ?? true ? null : transaction.notes?.trim(),
      createdAt: transaction.createdAt.toIso8601String().isEmpty
          ? now.toIso8601String()
          : transaction.createdAt.toIso8601String(),
    );

    final id = await exec.insert(
      DatabaseConstants.tableCashTransactions,
      model.toMap(),
    );

    final saved = transaction.copyWith(id: id);

    // إشعار المستمعين بتغير رصيد وحركات الصندوق
    AppDataNotifier.instance.notifyCashboxChanged(saved);

    return saved;
  }

  @override
  Future<CashTransaction> recordOwnerWithdrawal(
    int amount, {
    DateTime? date,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ValidationException('مبلغ سحب المالك يجب أن يكون أكبر من الصفر');
    }

    final now = DateTime.now();
    final txDate = date ?? now;

    final transaction = CashTransaction(
      id: 0,
      type: CashTransactionType.ownerWithdrawal,
      direction: CashFlowDirection.cashOut,
      amount: amount,
      transactionDate: txDate,
      referenceType: 'owner_withdrawal',
      description: 'مسحوبات شخصية لصاحب المحل',
      notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
      createdAt: now,
    );

    return await recordCashTransaction(transaction);
  }

  @override
  Future<CashTransaction> recordOtherDeposit(
    int amount, {
    DateTime? date,
    String? description,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ValidationException('مبلغ الإيداع يجب أن يكون أكبر من الصفر');
    }

    final now = DateTime.now();
    final txDate = date ?? now;
    final desc = description?.trim().isNotEmpty ?? false
        ? description!.trim()
        : 'إيداع نقدي إضافي في الصندوق';

    final transaction = CashTransaction(
      id: 0,
      type: CashTransactionType.otherDeposit,
      direction: CashFlowDirection.cashIn,
      amount: amount,
      transactionDate: txDate,
      referenceType: 'other_deposit',
      description: desc,
      notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
      createdAt: now,
    );

    return await recordCashTransaction(transaction);
  }
}
