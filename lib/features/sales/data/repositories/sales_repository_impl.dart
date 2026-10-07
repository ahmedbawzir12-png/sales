import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/domain/services/financial_flow_integration.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../customers/data/repositories/customer_ledger_repository_impl.dart';
import '../../../customers/domain/entities/customer_ledger_entry.dart';
import '../../../products/data/repositories/stock_movements_repository_impl.dart';
import '../../../products/domain/entities/stock_movement.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_invoice_item.dart';
import '../../domain/entities/sales_invoice_status.dart';
import '../../domain/entities/sales_payment_type.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/sales_calculation_service.dart';
import '../models/sales_invoice_item_model.dart';
import '../models/sales_invoice_model.dart';

import '../../../cash/domain/entities/cash_flow_direction.dart';
import '../../../cash/domain/entities/cash_transaction.dart';
import '../../../cash/domain/entities/cash_transaction_type.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../../cash/data/repositories/cashbox_repository_impl.dart';

/// تطبيق مستودع المبيعات وفواتير البيع باستخدام المعاملات الذرية (Transactions) في SQLite
class SalesRepositoryImpl implements SalesRepository {
  final DatabaseService _dbService;
  final StockMovementsRepositoryImpl _stockMovementsRepo;
  final CustomerLedgerRepositoryImpl _customerLedgerRepo;
  final FinancialFlowIntegrationService _financialService;
  final SalesCalculationService _calculationService;
  final CashboxRepository _cashboxRepo;

  SalesRepositoryImpl({
    DatabaseService? dbService,
    StockMovementsRepositoryImpl? stockMovementsRepo,
    CustomerLedgerRepositoryImpl? customerLedgerRepo,
    FinancialFlowIntegrationService? financialService,
    SalesCalculationService? calculationService,
    CashboxRepository? cashboxRepo,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _stockMovementsRepo = stockMovementsRepo ??
            StockMovementsRepositoryImpl(
                databaseService: dbService ?? DatabaseService.instance),
        _customerLedgerRepo = customerLedgerRepo ??
            CustomerLedgerRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance),
        _financialService =
            financialService ?? FinancialFlowIntegrationService.instance,
        _calculationService = calculationService ?? const SalesCalculationService(),
        _cashboxRepo = cashboxRepo ??
            CashboxRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance);

  @override
  Future<String> generateNextInvoiceNumber() async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'SAL-$datePrefix-';

    try {
      final db = await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT invoice_number FROM ${DatabaseConstants.tableSalesInvoices}
        WHERE invoice_number LIKE ?
        ORDER BY id DESC
        LIMIT 1
        ''',
        ['$prefix%'],
      );

      if (result.isEmpty) {
        return '${prefix}0001';
      }

      final lastNumber = result.first['invoice_number'] as String;
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
  Future<List<SalesInvoice>> getInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    String? searchQuery,
  }) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (customerId != null) {
        whereClauses.add('s.customer_id = ?');
        whereArgs.add(customerId);
      }

      if (paymentType != null) {
        whereClauses.add('s.payment_type = ?');
        whereArgs.add(paymentType.name);
      }

      if (status != null) {
        whereClauses.add('s.status = ?');
        whereArgs.add(status.name);
      }

      if (fromDate != null) {
        whereClauses.add('s.invoice_date >= ?');
        whereArgs.add(fromDate.toIso8601String().split('T').first);
      }

      if (toDate != null) {
        whereClauses.add('s.invoice_date <= ?');
        whereArgs.add(toDate.toIso8601String().split('T').first);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        whereClauses.add('(s.invoice_number LIKE ? OR c.name LIKE ? OR s.notes LIKE ?)');
        whereArgs.addAll([term, term, term]);
      }

      final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = '''
        SELECT 
          s.*,
          c.name AS customer_name
        FROM ${DatabaseConstants.tableSalesInvoices} s
        LEFT JOIN ${DatabaseConstants.tableCustomers} c ON s.customer_id = c.id
        $whereString
        ORDER BY s.id DESC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      return results.map((row) => SalesInvoiceModel.fromMap(row).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة فواتير المبيعات', e);
    }
  }

  @override
  Future<SalesInvoice> getInvoiceById(int id) async {
    try {
      final db = await _dbService.database;

      final invoiceRows = await db.rawQuery(
        '''
        SELECT 
          s.*,
          c.name AS customer_name
        FROM ${DatabaseConstants.tableSalesInvoices} s
        LEFT JOIN ${DatabaseConstants.tableCustomers} c ON s.customer_id = c.id
        WHERE s.id = ?
        LIMIT 1
        ''',
        [id],
      );

      if (invoiceRows.isEmpty) {
        throw NotFoundException('فاتورة المبيعات برقم ($id) غير موجودة');
      }

      final itemRows = await db.rawQuery(
        '''
        SELECT 
          i.*,
          p.name AS product_name,
          u.symbol AS unit_symbol
        FROM ${DatabaseConstants.tableSalesInvoiceItems} i
        JOIN ${DatabaseConstants.tableProducts} p ON i.product_id = p.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        WHERE i.sales_invoice_id = ?
        ORDER BY i.id ASC
        ''',
        [id],
      );

      final items = itemRows.map((r) => SalesInvoiceItemModel.fromMap(r).toEntity()).toList();
      return SalesInvoiceModel.fromMap(invoiceRows.first).toEntity(items: items);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تفاصيل فاتورة المبيعات رقم ($id)', e);
    }
  }

  @override
  Future<SalesInvoice> getInvoiceByNumber(String invoiceNumber) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        DatabaseConstants.tableSalesInvoices,
        columns: ['id'],
        where: 'invoice_number = ?',
        whereArgs: [invoiceNumber],
        limit: 1,
      );

      if (result.isEmpty) {
        throw NotFoundException('فاتورة المبيعات برقم ($invoiceNumber) غير موجودة');
      }

      return getInvoiceById(result.first['id'] as int);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل البحث عن الفاتورة رقم ($invoiceNumber)', e);
    }
  }

  @override
  Future<SalesInvoice> createInvoice(SalesInvoice invoice) async {
    // 1. التحقق من بنود الفاتورة
    if (invoice.items.isEmpty) {
      throw const ValidationException('يجب إضافة صنف واحد على الأقل في فاتورة المبيعات');
    }

    // 2. التحقق من العميل والبيع الآجل
    if (invoice.paymentType == SalesPaymentType.credit) {
      if (invoice.customerId == null || invoice.customerId == 0) {
        throw const ValidationException('البيع الآجل يتطلب تحديد العميل، لا يمكن البيع الآجل لزبون عام');
      }
    }

    // 3. التحقق الحسابي المالي
    final subtotal = _calculationService.calculateSubtotal(invoice.items);
    final total = _calculationService.calculateTotalAmount(
      subtotal: subtotal,
      discount: invoice.discount,
    );
    final remaining = _calculationService.calculateRemainingAmount(
      totalAmount: total,
      paidAmount: invoice.paidAmount,
      paymentType: invoice.paymentType,
    );

    // 4. تنفيذ العملية داخل معاملة ذرية تامة (SQLite Atomic Transaction)
    try {
      final db = await _dbService.database;

      return await db.transaction<SalesInvoice>((txn) async {
        final now = DateTime.now();

        // أ) التحقق من وجود العميل إذا تم تحديده
        String? customerName;
        if (invoice.customerId != null) {
          final custRows = await txn.query(
            DatabaseConstants.tableCustomers,
            where: 'id = ?',
            whereArgs: [invoice.customerId],
          );
          if (custRows.isEmpty) {
            throw NotFoundException('العميل المحدد برقم (${invoice.customerId}) غير موجود');
          }
          final custData = custRows.first;
          if ((custData['is_active'] as int? ?? 1) == 0) {
            throw const ValidationException('لا يمكن إنشاء فاتورة بيع لعميل معطل');
          }
          customerName = custData['name'] as String?;
        }

        // ب) التحقق من المخزون وتحديد تكلفة البضاعة وقت البيع لكل منتج
        final itemsToSave = <SalesInvoiceItem>[];
        for (final item in invoice.items) {
          final prodRows = await txn.query(
            DatabaseConstants.tableProducts,
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          if (prodRows.isEmpty) {
            throw NotFoundException('المنتج رقم (${item.productId}) غير موجود');
          }

          final prodData = prodRows.first;
          final prodName = prodData['name'] as String;
          final currentStock = (prodData['current_stock'] as num).toDouble();
          final averageCost = (prodData['average_cost'] as num).toDouble();

          // التحقق الصارم من توفر المخزون قبل البيع
          if (currentStock < item.quantity) {
            throw ValidationException(
              'لا يمكن إتمام البيع: الرصيد المتوفر في المستودع للمنتج "$prodName" هو ($currentStock)، بينما الكمية المطلوبة للبيع هي (${item.quantity}).',
            );
          }

          // تثبيت تكلفة الوحدة وقت البيع بدقة (unitCostAtSale)
          final lineCostTotal = item.quantity * averageCost;
          final verifiedLineTotal = _calculationService.calculateItemTotal(
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discount: item.discount,
          );

          itemsToSave.add(
            item.copyWith(
              unitCostAtSale: averageCost,
              costTotal: lineCostTotal,
              total: verifiedLineTotal,
              productName: prodName,
            ),
          );
        }

        // ج) إنشاء رأس فاتورة المبيعات
        final invoiceModel = SalesInvoiceModel(
          invoiceNumber: invoice.invoiceNumber,
          customerId: invoice.customerId,
          invoiceDate: invoice.invoiceDate.toIso8601String(),
          subtotal: subtotal,
          discount: invoice.discount,
          total: total,
          paidAmount: invoice.paymentType == SalesPaymentType.cash ? total : invoice.paidAmount,
          remainingAmount: remaining,
          paymentType: invoice.paymentType.name,
          status: SalesInvoiceStatus.completed.name,
          notes: invoice.notes,
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
        );

        final invoiceId = await txn.insert(
          DatabaseConstants.tableSalesInvoices,
          invoiceModel.toMap(),
        );

        // د) حفظ بنود الفاتورة وخصم المخزون وتسجيل حركة المخزون
        final savedItems = <SalesInvoiceItem>[];
        for (final item in itemsToSave) {
          final itemModel = SalesInvoiceItemModel.fromEntity(
            item.copyWith(salesInvoiceId: invoiceId),
          );

          final itemId = await txn.insert(
            DatabaseConstants.tableSalesInvoiceItems,
            itemModel.toMap(),
          );

          savedItems.add(item.copyWith(id: itemId, salesInvoiceId: invoiceId));

          // خصم المخزون وتسجيل Stock Movement المركزي
          await _stockMovementsRepo.recordMovementWithExecutor(
            txn,
            productId: item.productId,
            type: StockMovementType.sale,
            quantity: item.quantity,
            reason: 'فاتورة مبيعات رقم ${invoice.invoiceNumber}',
            reference: invoice.invoiceNumber,
            notes: 'بيع بسعر ${item.unitPrice} وتكلفة وقت البيع ${item.unitCostAtSale}',
          );
        }

        // هـ) تسجيل أثر البيع الآجل في أستاذ العميل (Customer Ledger) إن وجد مبلغ متبقي
        if (invoice.paymentType == SalesPaymentType.credit &&
            remaining > 0 &&
            invoice.customerId != null) {
          await _customerLedgerRepo.recordEntryWithExecutor(
            txn,
            CustomerLedgerEntry(
              id: 0,
              customerId: invoice.customerId!,
              transactionType: CustomerLedgerTransactionType.saleCredit,
              amount: remaining,
              transactionDate: invoice.invoiceDate,
              referenceType: 'sales_invoice',
              referenceId: invoiceId,
              notes: 'فاتورة مبيعات آجلة رقم ${invoice.invoiceNumber}',
              createdAt: now,
            ),
          );
        }

        // و) تسجيل حركة التدفق المالي في الصندوق (Cash In) للمبلغ المقبوض نقداً داخل نفس المعاملة الذرية
        final effectivePaid =
            invoice.paymentType == SalesPaymentType.cash ? total : invoice.paidAmount;
        if (effectivePaid > 0) {
          await _cashboxRepo.recordCashTransactionWithExecutor(
            txn,
            CashTransaction(
              id: 0,
              type: CashTransactionType.sale,
              direction: CashFlowDirection.cashIn,
              amount: effectivePaid,
              transactionDate: invoice.invoiceDate,
              referenceType: 'sales_invoice',
              referenceId: invoiceId,
              description: 'مبيعات ${invoice.paymentType.arabicLabel} (فاتورة رقم ${invoice.invoiceNumber})',
              createdAt: now,
            ),
          );

          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashIn,
              source: FinancialFlowSource.cashSale,
              amount: effectivePaid,
              referenceType: 'sales_invoice',
              referenceId: invoiceId,
              description: 'مبيعات ${invoice.paymentType.arabicLabel} (فاتورة رقم ${invoice.invoiceNumber})',
              date: invoice.invoiceDate,
            ),
          );
        }

        final saved = invoice.copyWith(
          id: invoiceId,
          subtotal: subtotal,
          totalAmount: total,
          paidAmount: effectivePaid,
          remainingAmount: remaining,
          status: SalesInvoiceStatus.completed,
          items: savedItems,
          customerName: customerName,
          createdAt: now,
          updatedAt: now,
        );

        AppDataNotifier.instance.notifyInventoryChanged();
        AppDataNotifier.instance.notifySalesChanged();
        if (invoice.paymentType == SalesPaymentType.credit || invoice.remainingAmount > 0) {
          AppDataNotifier.instance.notifyCustomersChanged();
        }

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء فاتورة المبيعات في قاعدة البيانات: $e', e);
    }
  }

  @override
  Future<void> cancelInvoice(int invoiceId, {String? reason}) async {
    try {
      final db = await _dbService.database;

      await db.transaction((txn) async {
        // 1. استرجاع الفاتورة والتأكد من أنها مكتملة
        final invoiceRows = await txn.query(
          DatabaseConstants.tableSalesInvoices,
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        if (invoiceRows.isEmpty) {
          throw NotFoundException('فاتورة المبيعات برقم ($invoiceId) غير موجودة');
        }

        final invoiceData = invoiceRows.first;
        final currentStatus = invoiceData['status'] as String;
        final invoiceNumber = invoiceData['invoice_number'] as String;
        final customerId = invoiceData['customer_id'] as int?;
        final remainingAmount = (invoiceData['remaining_amount'] as num).toInt();
        final paidAmount = (invoiceData['paid_amount'] as num).toInt();

        if (currentStatus == SalesInvoiceStatus.cancelled.name) {
          throw const ValidationException('هذه الفاتورة ملغاة مسبقاً');
        }

        // 2. استرجاع بنود الفاتورة لإعادة الكميات للمخزون
        final itemRows = await txn.query(
          DatabaseConstants.tableSalesInvoiceItems,
          where: 'sales_invoice_id = ?',
          whereArgs: [invoiceId],
        );

        for (final row in itemRows) {
          final productId = (row['product_id'] as num).toInt();
          final quantity = (row['quantity'] as num).toDouble();

          // إعادة الكميات للمخزون وتسجيل حركة مرتجع مبيعات عكسية (saleReturn)
          await _stockMovementsRepo.recordMovementWithExecutor(
            txn,
            productId: productId,
            type: StockMovementType.saleReturn,
            quantity: quantity,
            reason: 'إلغاء فاتورة مبيعات رقم $invoiceNumber${reason != null ? " ($reason)" : ""}',
            reference: invoiceNumber,
            notes: 'إرجاع تلقائي للمخزون إثر إلغاء الفاتورة',
          );
        }

        final now = DateTime.now();

        // 3. تسوية أستاذ العميل في حال وجود دين مسجل
        if (remainingAmount > 0 && customerId != null) {
          await _customerLedgerRepo.recordEntryWithExecutor(
            txn,
            CustomerLedgerEntry(
              id: 0,
              customerId: customerId,
              transactionType: CustomerLedgerTransactionType.cancellation,
              amount: remainingAmount,
              transactionDate: now,
              referenceType: 'sales_invoice',
              referenceId: invoiceId,
              notes: 'إلغاء أثر الدين لفاتورة المبيعات رقم $invoiceNumber',
              createdAt: now,
            ),
          );
        }

        // 4. تسجيل حركة استرداد نقدي من الصندوق إن كان العميل دفع مبلغاً نقدياً
        if (paidAmount > 0) {
          await _cashboxRepo.recordCashTransactionWithExecutor(
            txn,
            CashTransaction(
              id: 0,
              type: CashTransactionType.salesReturnRefund,
              direction: CashFlowDirection.cashOut,
              amount: paidAmount,
              transactionDate: now,
              referenceType: 'sales_invoice_cancellation',
              referenceId: invoiceId,
              description: 'استرداد نقدي إثر إلغاء فاتورة مبيعات رقم $invoiceNumber',
              createdAt: now,
            ),
          );

          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashOut,
              source: FinancialFlowSource.salesReturnRefund,
              amount: paidAmount,
              referenceType: 'sales_invoice_cancellation',
              referenceId: invoiceId,
              description: 'استرداد نقدي إثر إلغاء فاتورة مبيعات رقم $invoiceNumber',
              date: now,
            ),
          );
        }

        // 5. تحديث حالة الفاتورة وتصفير المتبقي
        await txn.update(
          DatabaseConstants.tableSalesInvoices,
          {
            'status': SalesInvoiceStatus.cancelled.name,
            'remaining_amount': 0,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        AppDataNotifier.instance.notifyInventoryChanged();
        AppDataNotifier.instance.notifySalesChanged();
        AppDataNotifier.instance.notifyCustomersChanged();
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إلغاء فاتورة المبيعات رقم ($invoiceId)', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getSalesSummaryMetrics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>["status = 'completed'"];
      final whereArgs = <dynamic>[];

      if (fromDate != null) {
        whereClauses.add('invoice_date >= ?');
        whereArgs.add(fromDate.toIso8601String().split('T').first);
      }

      if (toDate != null) {
        whereClauses.add('invoice_date <= ?');
        whereArgs.add(toDate.toIso8601String().split('T').first);
      }

      final whereString = 'WHERE ${whereClauses.join(' AND ')}';

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) AS total_invoices,
          COALESCE(SUM(total), 0) AS total_sales,
          COALESCE(SUM(paid_amount), 0) AS total_paid,
          COALESCE(SUM(CASE WHEN payment_type = 'credit' THEN remaining_amount ELSE 0 END), 0) AS total_remaining
        FROM ${DatabaseConstants.tableSalesInvoices}
        $whereString
      ''', whereArgs);

      final row = result.first;
      return {
        'totalInvoices': (row['total_invoices'] as num?)?.toInt() ?? 0,
        'totalSales': (row['total_sales'] as num?)?.toInt() ?? 0,
        'totalPaid': (row['total_paid'] as num?)?.toInt() ?? 0,
        'totalRemaining': (row['total_remaining'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع المؤشرات الإجمالية للمبيعات', e);
    }
  }
}
