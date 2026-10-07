import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/domain/services/financial_flow_integration.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../domain/entities/supplier_ledger_entry.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/repositories/supplier_payments_repository.dart';
import '../models/supplier_payment_model.dart';
import 'supplier_ledger_repository_impl.dart';

import '../../../cash/domain/entities/cash_flow_direction.dart';
import '../../../cash/domain/entities/cash_transaction.dart';
import '../../../cash/domain/entities/cash_transaction_type.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../../cash/data/repositories/cashbox_repository_impl.dart';

class SupplierPaymentsRepositoryImpl implements SupplierPaymentsRepository {
  final DatabaseService _dbService;
  final SupplierLedgerRepositoryImpl _ledgerRepo;
  final FinancialFlowIntegrationService _financialService;
  final CashboxRepository _cashboxRepo;

  SupplierPaymentsRepositoryImpl({
    DatabaseService? dbService,
    SupplierLedgerRepositoryImpl? ledgerRepo,
    FinancialFlowIntegrationService? financialService,
    CashboxRepository? cashboxRepo,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _ledgerRepo = ledgerRepo ??
            SupplierLedgerRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance),
        _financialService =
            financialService ?? FinancialFlowIntegrationService.instance,
        _cashboxRepo = cashboxRepo ??
            CashboxRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance);

  @override
  Future<String> generateNextPaymentNumber([DatabaseExecutor? executor]) async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'SPAY-$datePrefix-';

    try {
      final db = executor ?? await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT payment_number FROM ${DatabaseConstants.tableSupplierPayments}
        WHERE payment_number LIKE ?
        ORDER BY id DESC
        LIMIT 1
        ''',
        ['$prefix%'],
      );

      if (result.isEmpty) {
        return '${prefix}0001';
      }

      final lastNumber = result.first['payment_number'] as String;
      final parts = lastNumber.split('-');
      if (parts.length >= 3) {
        final lastSeq = int.tryParse(parts[2]) ?? 0;
        final nextSeq = (lastSeq + 1).toString().padLeft(4, '0');
        return '$prefix$nextSeq';
      }
      return '${prefix}0001';
    } catch (e) {
      return '${prefix}0001';
    }
  }

  @override
  Future<List<SupplierPayment>> getPayments({int? supplierId}) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (supplierId != null) {
        whereClauses.add('p.supplier_id = ?');
        whereArgs.add(supplierId);
      }

      final whereString =
          whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = '''
        SELECT 
          p.*,
          s.name AS supplier_name
        FROM ${DatabaseConstants.tableSupplierPayments} p
        JOIN ${DatabaseConstants.tableSuppliers} s ON p.supplier_id = s.id
        $whereString
        ORDER BY p.payment_date DESC, p.id DESC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      return results
          .map((row) => SupplierPaymentModel.fromMap(row).toEntity())
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل دفعات الموردين', e);
    }
  }

  @override
  Future<SupplierPayment> recordPayment(SupplierPayment payment) async {
    if (payment.amount <= 0) {
      throw const ValidationException('مبلغ الدفعة يجب أن يكون أكبر من الصفر');
    }

    try {
      final db = await _dbService.database;

      return await db.transaction<SupplierPayment>((txn) async {
        // 1. التحقق من وجود المورد وأنه نشط
        final supplierRows = await txn.query(
          DatabaseConstants.tableSuppliers,
          where: 'id = ?',
          whereArgs: [payment.supplierId],
          limit: 1,
        );

        if (supplierRows.isEmpty) {
          throw const NotFoundException('المورد المحدد غير مسجل في النظام');
        }

        final supplier = supplierRows.first;
        if ((supplier['is_active'] as int? ?? 1) == 0) {
          throw const ValidationException('لا يمكن تسجيل دفعة لمورد معطل');
        }
        final supplierName = supplier['name'] as String;

        // 2. التحقق من الدين المستحق الفعلي للمورد من واقع الأستاذ العام
        final currentDebt = await _ledgerRepo.getSupplierBalanceWithExecutor(
            txn, payment.supplierId);

        if (currentDebt <= 0) {
          throw const ValidationException(
              'لا يوجد دين مستحق لهذا المورد لتسجيل دفعة');
        }

        if (payment.amount > currentDebt) {
          throw ValidationException(
            'لا يمكن تسجيل دفعة بمبلغ (${payment.amount}) لأنها تتجاوز إجمالي دين المورد المستحق ($currentDebt)',
          );
        }

        final now = DateTime.now();
        final paymentNumber = payment.paymentNumber.trim().isNotEmpty
            ? payment.paymentNumber.trim()
            : await generateNextPaymentNumber(txn);

        // 3. التحقق من عدم تكرار رقم الدفعة
        final existing = await txn.query(
          DatabaseConstants.tableSupplierPayments,
          where: 'payment_number = ?',
          whereArgs: [paymentNumber],
        );
        if (existing.isNotEmpty) {
          throw ValidationException('رقم الدفعة ($paymentNumber) مسجل مسبقاً');
        }

        // 4. إدراج الدفعة
        final paymentModel = SupplierPaymentModel(
          id: 0,
          paymentNumber: paymentNumber,
          supplierId: payment.supplierId,
          supplierName: supplierName,
          amount: payment.amount,
          paymentDate: payment.paymentDate.toIso8601String(),
          paymentMethod: payment.paymentMethod,
          reference: payment.reference?.trim(),
          notes: payment.notes?.trim(),
          createdAt: now.toIso8601String(),
        );

        final paymentId = await txn.insert(
          DatabaseConstants.tableSupplierPayments,
          paymentModel.toMap(),
        );

        // 5. تسجيل حركة في أستاذ المورد (Supplier Ledger)
        await _ledgerRepo.recordEntryWithExecutor(
          txn,
          SupplierLedgerEntry(
            id: 0,
            supplierId: payment.supplierId,
            transactionType: SupplierLedgerTransactionType.payment,
            amount: payment.amount,
            transactionDate: payment.paymentDate,
            referenceType: 'supplier_payment',
            referenceId: paymentId,
            notes: payment.notes ?? 'سداد دفعة نقدية للمورد رقم $paymentNumber',
            createdAt: now,
          ),
        );

        // 6. تحديث حقل current_balance في جدول suppliers لحفظ الاتساق السريع
        final newBalance = currentDebt - payment.amount;
        await txn.update(
          DatabaseConstants.tableSuppliers,
          {
            'current_balance': newBalance,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [payment.supplierId],
        );

        // 7. تسجيل حركة الصندوق النقدية (Cash Out) داخل نفس المعاملة الذرية
        // يتم التحقق التلقائي من أن رصيد الصندوق يكفي لصرف الدفعة لمنع الرصيد السالب
        await _cashboxRepo.recordCashTransactionWithExecutor(
          txn,
          CashTransaction(
            id: 0,
            type: CashTransactionType.supplierPayment,
            direction: CashFlowDirection.cashOut,
            amount: payment.amount,
            transactionDate: payment.paymentDate,
            referenceType: 'supplier_payment',
            referenceId: paymentId,
            description: 'سداد دفعة للمورد $supplierName (سند رقم $paymentNumber)',
            notes: payment.notes,
            createdAt: now,
          ),
        );

        // 8. إشعار التدفق المالي التكاملي
        _financialService.dispatchFlow(
          FinancialFlowRecord(
            type: FinancialFlowType.cashOut,
            source: FinancialFlowSource.supplierPayment,
            amount: payment.amount,
            referenceType: 'supplier_payment',
            referenceId: paymentId,
            description: 'سداد دفعة للمورد $supplierName (رقم $paymentNumber)',
            date: payment.paymentDate,
          ),
        );

        final saved = payment.copyWith(
          id: paymentId,
          paymentNumber: paymentNumber,
          supplierName: supplierName,
          createdAt: now,
        );

        AppDataNotifier.instance.notifySuppliersChanged();

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل دفعة المورد في قاعدة البيانات: $e', e);
    }
  }
}
