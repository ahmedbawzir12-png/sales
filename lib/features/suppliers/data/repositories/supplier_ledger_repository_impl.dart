import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../domain/entities/supplier_ledger_entry.dart';
import '../../domain/repositories/supplier_ledger_repository.dart';
import '../models/supplier_ledger_entry_model.dart';

class SupplierLedgerRepositoryImpl implements SupplierLedgerRepository {
  final DatabaseService _dbService;

  SupplierLedgerRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<SupplierLedgerEntry>> getLedgerEntries(int supplierId) async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        DatabaseConstants.tableSupplierLedger,
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'transaction_date DESC, id DESC',
      );

      return results
          .map((row) => SupplierLedgerEntryModel.fromMap(row).toEntity())
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع حركات أستاذ المورد', e);
    }
  }

  @override
  Future<int> getSupplierBalance(int supplierId) async {
    try {
      final db = await _dbService.database;
      return await getSupplierBalanceWithExecutor(db, supplierId);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب رصيد المورد من الأستاذ العام', e);
    }
  }

  /// حساب الرصيد باستخدام منفذ معاملات محدد لدعم الـ Transactions
  Future<int> getSupplierBalanceWithExecutor(
      DatabaseExecutor executor, int supplierId) async {
    final results = await executor.rawQuery('''
      SELECT COALESCE(
        SUM(CASE 
          WHEN transaction_type = 'purchase_credit' THEN amount 
          WHEN transaction_type IN ('payment', 'purchase_return', 'cancellation') THEN -amount 
          WHEN transaction_type = 'adjustment' THEN amount 
          ELSE 0 
        END), 
        0
      ) AS balance
      FROM ${DatabaseConstants.tableSupplierLedger}
      WHERE supplier_id = ?
    ''', [supplierId]);

    return (results.first['balance'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> recordEntry(SupplierLedgerEntry entry) async {
    try {
      final db = await _dbService.database;
      return await recordEntryWithExecutor(db, entry);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل حركة في أستاذ المورد', e);
    }
  }

  /// تسجيل حركة باستخدام منفذ معاملات محدد داخل Transactions
  Future<int> recordEntryWithExecutor(
      DatabaseExecutor executor, SupplierLedgerEntry entry) async {
    final model = SupplierLedgerEntryModel.fromEntity(entry);
    return await executor.insert(
      DatabaseConstants.tableSupplierLedger,
      model.toMap(),
    );
  }
}
