import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import '../models/customer_ledger_entry_model.dart';

class CustomerLedgerRepositoryImpl implements CustomerLedgerRepository {
  final DatabaseService _dbService;

  CustomerLedgerRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<CustomerLedgerEntry>> getLedgerEntries(int customerId) async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        DatabaseConstants.tableCustomerLedger,
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'transaction_date DESC, id DESC',
      );

      return results
          .map((row) => CustomerLedgerEntryModel.fromMap(row).toEntity())
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع حركات أستاذ العميل', e);
    }
  }

  @override
  Future<int> getCustomerBalance(int customerId) async {
    try {
      final db = await _dbService.database;
      return await getCustomerBalanceWithExecutor(db, customerId);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب رصيد العميل من الأستاذ العام', e);
    }
  }

  /// حساب الرصيد باستخدام منفذ معاملات محدد لدعم الـ Transactions
  Future<int> getCustomerBalanceWithExecutor(
      DatabaseExecutor executor, int customerId) async {
    final results = await executor.rawQuery('''
      SELECT COALESCE(
        SUM(CASE 
          WHEN transaction_type = 'sale_credit' THEN amount 
          WHEN transaction_type IN ('payment', 'sales_return', 'cancellation') THEN -amount 
          WHEN transaction_type = 'adjustment' THEN amount 
          ELSE 0 
        END), 
        0
      ) AS balance
      FROM ${DatabaseConstants.tableCustomerLedger}
      WHERE customer_id = ?
    ''', [customerId]);

    return (results.first['balance'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> recordEntry(CustomerLedgerEntry entry) async {
    try {
      final db = await _dbService.database;
      return await recordEntryWithExecutor(db, entry);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل حركة في أستاذ العميل', e);
    }
  }

  /// تسجيل حركة باستخدام منفذ معاملات محدد داخل Transactions
  Future<int> recordEntryWithExecutor(
      DatabaseExecutor executor, CustomerLedgerEntry entry) async {
    final model = CustomerLedgerEntryModel.fromEntity(entry);
    return await executor.insert(
      DatabaseConstants.tableCustomerLedger,
      model.toMap(),
    );
  }
}
