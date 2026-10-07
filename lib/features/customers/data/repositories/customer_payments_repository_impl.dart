import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/domain/services/financial_flow_integration.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/entities/customer_payment.dart';
import '../../domain/repositories/customer_payments_repository.dart';
import '../models/customer_payment_model.dart';
import 'customer_ledger_repository_impl.dart';

import '../../../cash/domain/entities/cash_flow_direction.dart';
import '../../../cash/domain/entities/cash_transaction.dart';
import '../../../cash/domain/entities/cash_transaction_type.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../../cash/data/repositories/cashbox_repository_impl.dart';

class CustomerPaymentsRepositoryImpl implements CustomerPaymentsRepository {
  final DatabaseService _dbService;
  final CustomerLedgerRepositoryImpl _ledgerRepo;
  final FinancialFlowIntegrationService _financialService;
  final CashboxRepository _cashboxRepo;

  CustomerPaymentsRepositoryImpl({
    DatabaseService? dbService,
    CustomerLedgerRepositoryImpl? ledgerRepo,
    FinancialFlowIntegrationService? financialService,
    CashboxRepository? cashboxRepo,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _ledgerRepo = ledgerRepo ??
            CustomerLedgerRepositoryImpl(
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
    final prefix = 'CPAY-$datePrefix-';

    try {
      final db = executor ?? await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT payment_number FROM ${DatabaseConstants.tableCustomerPayments}
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
  Future<List<CustomerPayment>> getPayments({int? customerId}) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (customerId != null) {
        whereClauses.add('p.customer_id = ?');
        whereArgs.add(customerId);
      }

      final whereString =
          whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = '''
        SELECT 
          p.*,
          c.name AS customer_name
        FROM ${DatabaseConstants.tableCustomerPayments} p
        JOIN ${DatabaseConstants.tableCustomers} c ON p.customer_id = c.id
        $whereString
        ORDER BY p.payment_date DESC, p.id DESC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      return results
          .map((row) => CustomerPaymentModel.fromMap(row).toEntity())
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل دفعات العملاء', e);
    }
  }

  @override
  Future<CustomerPayment> recordPayment(CustomerPayment payment) async {
    if (payment.amount <= 0) {
      throw const ValidationException('مبلغ الدفعة يجب أن يكون أكبر من الصفر');
    }

    try {
      final db = await _dbService.database;

      return await db.transaction<CustomerPayment>((txn) async {
        // 1. التحقق من وجود العميل وأنه نشط
        final customerRows = await txn.query(
          DatabaseConstants.tableCustomers,
          where: 'id = ?',
          whereArgs: [payment.customerId],
          limit: 1,
        );

        if (customerRows.isEmpty) {
          throw const NotFoundException('العميل المحدد غير موجود في النظام');
        }

        final customer = customerRows.first;
        if ((customer['is_active'] as int? ?? 1) == 0) {
          throw const ValidationException('لا يمكن تسجيل دفعة لعميل معطل');
        }
        final customerName = customer['name'] as String;

        // 2. التحقق من الدين المستحق الفعلي من واقع الأستاذ العام
        final currentDebt = await _ledgerRepo.getCustomerBalanceWithExecutor(
            txn, payment.customerId);

        if (currentDebt <= 0) {
          throw const ValidationException(
              'لا يوجد دين مستحق على هذا العميل لتسجيل دفعة');
        }

        if (payment.amount > currentDebt) {
          throw ValidationException(
            'لا يمكن تسجيل دفعة بمبلغ (${payment.amount}) لأنها تتجاوز إجمالي الدين المستحق الحالي للعميل ($currentDebt)',
          );
        }

        final now = DateTime.now();
        final paymentNumber = payment.paymentNumber.trim().isNotEmpty
            ? payment.paymentNumber.trim()
            : await generateNextPaymentNumber(txn);

        // 3. التحقق من عدم تكرار رقم الدفعة
        final existing = await txn.query(
          DatabaseConstants.tableCustomerPayments,
          where: 'payment_number = ?',
          whereArgs: [paymentNumber],
        );
        if (existing.isNotEmpty) {
          throw ValidationException('رقم الدفعة ($paymentNumber) مسجل مسبقاً');
        }

        // 4. إدراج الدفعة
        final paymentModel = CustomerPaymentModel(
          id: 0,
          paymentNumber: paymentNumber,
          customerId: payment.customerId,
          customerName: customerName,
          amount: payment.amount,
          paymentDate: payment.paymentDate.toIso8601String(),
          paymentMethod: payment.paymentMethod,
          reference: payment.reference?.trim(),
          notes: payment.notes?.trim(),
          createdAt: now.toIso8601String(),
        );

        final paymentId = await txn.insert(
          DatabaseConstants.tableCustomerPayments,
          paymentModel.toMap(),
        );

        // 5. تسجيل حركة في أستاذ العميل (Customer Ledger)
        await _ledgerRepo.recordEntryWithExecutor(
          txn,
          CustomerLedgerEntry(
            id: 0,
            customerId: payment.customerId,
            transactionType: CustomerLedgerTransactionType.payment,
            amount: payment.amount,
            transactionDate: payment.paymentDate,
            referenceType: 'customer_payment',
            referenceId: paymentId,
            notes: payment.notes ?? 'سداد دفعة نقدية رقم $paymentNumber',
            createdAt: now,
          ),
        );

        // 6. تسجيل حركة التدفق في الصندوق النقدية (Cash In) داخل نفس المعاملة الذرية
        await _cashboxRepo.recordCashTransactionWithExecutor(
          txn,
          CashTransaction(
            id: 0,
            type: CashTransactionType.customerPayment,
            direction: CashFlowDirection.cashIn,
            amount: payment.amount,
            transactionDate: payment.paymentDate,
            referenceType: 'customer_payment',
            referenceId: paymentId,
            description: 'قبض دفعة من العميل $customerName (سند رقم $paymentNumber)',
            notes: payment.notes,
            createdAt: now,
          ),
        );

        // 7. إشعار التدفق المالي التكاملي
        _financialService.dispatchFlow(
          FinancialFlowRecord(
            type: FinancialFlowType.cashIn,
            source: FinancialFlowSource.customerPayment,
            amount: payment.amount,
            referenceType: 'customer_payment',
            referenceId: paymentId,
            description: 'قبض دفعة من العميل $customerName (رقم $paymentNumber)',
            date: payment.paymentDate,
          ),
        );

        final saved = payment.copyWith(
          id: paymentId,
          paymentNumber: paymentNumber,
          customerName: customerName,
          createdAt: now,
        );

        AppDataNotifier.instance.notifyCustomersChanged();

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل دفعة العميل في قاعدة البيانات: $e', e);
    }
  }
}
