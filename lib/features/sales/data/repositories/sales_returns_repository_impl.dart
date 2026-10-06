import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/domain/services/financial_flow_integration.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../customers/data/repositories/customer_ledger_repository_impl.dart';
import '../../../customers/domain/entities/customer_ledger_entry.dart';
import '../../../products/data/repositories/stock_movements_repository_impl.dart';
import '../../../products/domain/entities/stock_movement.dart';
import '../../../purchases/domain/services/weighted_average_cost_calculator.dart';
import '../../domain/entities/sales_return.dart';
import '../../domain/entities/sales_return_item.dart';
import '../../domain/repositories/sales_returns_repository.dart';
import '../models/sales_return_item_model.dart';
import '../models/sales_return_model.dart';

class SalesReturnsRepositoryImpl implements SalesReturnsRepository {
  final DatabaseService _dbService;
  final StockMovementsRepositoryImpl _stockMovementsRepo;
  final CustomerLedgerRepositoryImpl _customerLedgerRepo;
  final FinancialFlowIntegrationService _financialService;

  SalesReturnsRepositoryImpl({
    DatabaseService? dbService,
    StockMovementsRepositoryImpl? stockMovementsRepo,
    CustomerLedgerRepositoryImpl? customerLedgerRepo,
    FinancialFlowIntegrationService? financialService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _stockMovementsRepo = stockMovementsRepo ??
            StockMovementsRepositoryImpl(
                databaseService: dbService ?? DatabaseService.instance),
        _customerLedgerRepo = customerLedgerRepo ??
            CustomerLedgerRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance),
        _financialService =
            financialService ?? FinancialFlowIntegrationService.instance;

  @override
  Future<String> generateNextReturnNumber([DatabaseExecutor? executor]) async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'SRET-$datePrefix-';

    try {
      final db = executor ?? await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT return_number FROM ${DatabaseConstants.tableSalesReturns}
        WHERE return_number LIKE ?
        ORDER BY id DESC
        LIMIT 1
        ''',
        ['$prefix%'],
      );

      if (result.isEmpty) {
        return '${prefix}0001';
      }

      final lastNumber = result.first['return_number'] as String;
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
  Future<List<SalesReturn>> getReturns({int? invoiceId, int? customerId}) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (invoiceId != null) {
        whereClauses.add('sr.sales_invoice_id = ?');
        whereArgs.add(invoiceId);
      }

      if (customerId != null) {
        whereClauses.add('sr.customer_id = ?');
        whereArgs.add(customerId);
      }

      final whereString =
          whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = '''
        SELECT 
          sr.*,
          si.invoice_number,
          c.name AS customer_name
        FROM ${DatabaseConstants.tableSalesReturns} sr
        JOIN ${DatabaseConstants.tableSalesInvoices} si ON sr.sales_invoice_id = si.id
        LEFT JOIN ${DatabaseConstants.tableCustomers} c ON sr.customer_id = c.id
        $whereString
        ORDER BY sr.return_date DESC, sr.id DESC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      return results.map((row) => SalesReturnModel.fromMap(row).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل مرتجعات المبيعات', e);
    }
  }

  @override
  Future<SalesReturn> getReturnById(int id) async {
    try {
      final db = await _dbService.database;
      final sql = '''
        SELECT 
          sr.*,
          si.invoice_number,
          c.name AS customer_name
        FROM ${DatabaseConstants.tableSalesReturns} sr
        JOIN ${DatabaseConstants.tableSalesInvoices} si ON sr.sales_invoice_id = si.id
        LEFT JOIN ${DatabaseConstants.tableCustomers} c ON sr.customer_id = c.id
        WHERE sr.id = ?
        LIMIT 1
      ''';

      final results = await db.rawQuery(sql, [id]);
      if (results.isEmpty) {
        throw const NotFoundException('مرتجع المبيعات المطلوب غير موجود');
      }

      final returnEntity = SalesReturnModel.fromMap(results.first).toEntity();

      // جلب البنود
      final itemsSql = '''
        SELECT 
          sri.*,
          p.name AS product_name
        FROM ${DatabaseConstants.tableSalesReturnItems} sri
        JOIN ${DatabaseConstants.tableProducts} p ON sri.product_id = p.id
        WHERE sri.sales_return_id = ?
      ''';
      final itemRows = await db.rawQuery(itemsSql, [id]);
      final items =
          itemRows.map((r) => SalesReturnItemModel.fromMap(r).toEntity()).toList();

      return returnEntity.copyWith(items: items);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تفاصيل مرتجع المبيعات', e);
    }
  }

  @override
  Future<List<SalesReturnAvailableItem>> getAvailableReturnItems(
      int salesInvoiceId) async {
    try {
      final db = await _dbService.database;

      // استعلام يجمع البنود الأصلية والكميات المرتجعة سابقاً
      final sql = '''
        SELECT 
          sii.product_id,
          p.name AS product_name,
          sii.quantity AS original_qty,
          sii.unit_price,
          sii.unit_cost_at_sale,
          COALESCE((
            SELECT SUM(sri.quantity)
            FROM ${DatabaseConstants.tableSalesReturnItems} sri
            JOIN ${DatabaseConstants.tableSalesReturns} sr ON sri.sales_return_id = sr.id
            WHERE sr.sales_invoice_id = sii.sales_invoice_id 
              AND sri.product_id = sii.product_id
              AND sr.status = 'completed'
          ), 0.0) AS returned_qty
        FROM ${DatabaseConstants.tableSalesInvoiceItems} sii
        JOIN ${DatabaseConstants.tableProducts} p ON sii.product_id = p.id
        WHERE sii.sales_invoice_id = ?
      ''';

      final results = await db.rawQuery(sql, [salesInvoiceId]);

      return results.map((row) {
        final original = (row['original_qty'] as num).toDouble();
        final returned = (row['returned_qty'] as num).toDouble();
        final available = (original - returned).clamp(0.0, original);

        return SalesReturnAvailableItem(
          productId: (row['product_id'] as num).toInt(),
          productName: row['product_name'] as String,
          originalQuantity: original,
          alreadyReturnedQuantity: returned,
          availableQuantity: available,
          unitPrice: (row['unit_price'] as num).toInt(),
          unitCostAtSale: (row['unit_cost_at_sale'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع البنود المتاحة للإرجاع', e);
    }
  }

  @override
  Future<SalesReturn> createReturn(SalesReturn salesReturn) async {
    if (salesReturn.items.isEmpty) {
      throw const ValidationException('يجب تحديد صنف واحد على الأقل للإرجاع');
    }

    try {
      final db = await _dbService.database;

      return await db.transaction<SalesReturn>((txn) async {
        // 1. التحقق من وجود الفاتورة الأصلية وأنها مكتملة
        final invoiceRows = await txn.query(
          DatabaseConstants.tableSalesInvoices,
          where: 'id = ?',
          whereArgs: [salesReturn.salesInvoiceId],
          limit: 1,
        );

        if (invoiceRows.isEmpty) {
          throw const NotFoundException('فاتورة المبيعات الأصلية غير موجودة');
        }

        final invoice = invoiceRows.first;
        final invoiceStatus = invoice['status'] as String;
        if (invoiceStatus != 'completed') {
          throw const ValidationException(
              'لا يمكن إنشاء مرتجع لفاتورة مبيعات ملغاة أو غير مكتملة');
        }

        final invoiceNumber = invoice['invoice_number'] as String;
        final invoiceCustomerId = invoice['customer_id'] as int?;
        final paymentType = invoice['payment_type'] as String;
        final invoiceRemaining = (invoice['remaining_amount'] as num).toInt();

        // 2. التحقق الصارم من الكميات المتاحة للإرجاع لكل بند
        final availableItems =
            await _getAvailableItemsWithExecutor(txn, salesReturn.salesInvoiceId);
        final availableMap = {for (var a in availableItems) a.productId: a};

        int totalReturnAmount = 0;
        final verifiedItems = <SalesReturnItem>[];

        for (final item in salesReturn.items) {
          if (item.quantity <= 0) continue;

          final available = availableMap[item.productId];
          if (available == null) {
            throw ValidationException(
                'المنتج رقم (${item.productId}) لم يكن ضمن فاتورة المبيعات الأصلية');
          }

          if (item.quantity > available.availableQuantity) {
            throw ValidationException(
              'الكمية المراد إرجاعها للمنتج "${available.productName}" هي (${item.quantity}) وتتجاوز الكمية المتاحة للإرجاع (${available.availableQuantity}).',
            );
          }

          final lineTotal = (item.quantity * available.unitPrice).round();
          totalReturnAmount += lineTotal;

          verifiedItems.add(item.copyWith(
            productName: available.productName,
            unitPrice: available.unitPrice,
            unitCostAtSale: available.unitCostAtSale,
            total: lineTotal,
          ));
        }

        if (verifiedItems.isEmpty) {
          throw const ValidationException('يجب إدخال كمية إرجاع أكبر من الصفر');
        }

        final returnNumber = salesReturn.returnNumber.trim().isNotEmpty
            ? salesReturn.returnNumber.trim()
            : await generateNextReturnNumber(txn);

        // فحص تكرار رقم المرتجع
        final existingRet = await txn.query(
          DatabaseConstants.tableSalesReturns,
          where: 'return_number = ?',
          whereArgs: [returnNumber],
        );
        if (existingRet.isNotEmpty) {
          throw ValidationException('رقم المرتجع "$returnNumber" مسجل مسبقاً');
        }

        // 3. احتساب الأثر المالي (تخفيض دين أو استرداد نقدي)
        int debtReduction = 0;
        int refundCash = totalReturnAmount;

        if (paymentType == 'credit' && invoiceCustomerId != null) {
          final customerDebt = await _customerLedgerRepo
              .getCustomerBalanceWithExecutor(txn, invoiceCustomerId);

          // تخفيض الدين بما لا يتجاوز متبقي الفاتورة وبما لا يتجاوز دين العميل الإجمالي
          final maxAllowedDebtReduction =
              customerDebt < invoiceRemaining ? customerDebt : invoiceRemaining;
          
          if (maxAllowedDebtReduction > 0) {
            debtReduction = totalReturnAmount <= maxAllowedDebtReduction
                ? totalReturnAmount
                : maxAllowedDebtReduction;
            refundCash = totalReturnAmount - debtReduction;
          } else {
            debtReduction = 0;
            refundCash = totalReturnAmount;
          }
        }

        final now = DateTime.now();

        // 4. إدراج رأس المرتجع
        final returnModel = SalesReturnModel(
          id: 0,
          returnNumber: returnNumber,
          salesInvoiceId: salesReturn.salesInvoiceId,
          salesInvoiceNumber: invoiceNumber,
          customerId: invoiceCustomerId,
          returnDate: salesReturn.returnDate.toIso8601String(),
          total: totalReturnAmount,
          refundAmount: refundCash,
          debtReductionAmount: debtReduction,
          status: 'completed',
          notes: salesReturn.notes?.trim(),
          createdAt: now.toIso8601String(),
        );

        final returnId = await txn.insert(
          DatabaseConstants.tableSalesReturns,
          returnModel.toMap(),
        );

        // 5. إدراج البنود وزيادة المخزون واستعادة التكلفة التاريخية
        final savedItems = <SalesReturnItem>[];
        for (final item in verifiedItems) {
          final itemModel = SalesReturnItemModel.fromEntity(
            item.copyWith(salesReturnId: returnId),
          );

          final itemId = await txn.insert(
            DatabaseConstants.tableSalesReturnItems,
            itemModel.toMap(),
          );

          savedItems.add(item.copyWith(id: itemId, salesReturnId: returnId));

          // جلب رصيد وتكلفة المنتج قبل الإرجاع
          final prodRows = await txn.query(
            DatabaseConstants.tableProducts,
            columns: ['id', 'current_stock', 'average_cost'],
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          final currentStock = (prodRows.first['current_stock'] as num).toDouble();
          final currentAvgCost = (prodRows.first['average_cost'] as num).toDouble();

          // زيادة رصيد المخزون وتسجيل حركة المخزون عبر الدالة المركزية
          await _stockMovementsRepo.recordMovementWithExecutor(
            txn,
            productId: item.productId,
            type: StockMovementType.saleReturn,
            quantity: item.quantity,
            reason: 'مرتجع مبيعات رقم $returnNumber لفاتورة $invoiceNumber',
            reference: returnNumber,
            notes: 'إرجاع بتكلفة بيع تاريخية ${item.unitCostAtSale}',
          );

          // استعادة التكلفة التاريخية: تحديث متوسط التكلفة المرجح بإضافة الكمية المرتجعة بتكلفتها الأصلية
          final updatedAvgCost = WeightedAverageCostCalculator.calculateNewAverageCost(
            currentStock: currentStock,
            currentAverageCost: currentAvgCost,
            addedQuantity: item.quantity,
            addedUnitCost: item.unitCostAtSale,
          );

          await txn.update(
            DatabaseConstants.tableProducts,
            {'average_cost': updatedAvgCost},
            where: 'id = ?',
            whereArgs: [item.productId],
          );
        }

        // 6. تسجيل الأثر المالي في أستاذ العميل إن وجد تخفيض دين
        if (debtReduction > 0 && invoiceCustomerId != null) {
          await _customerLedgerRepo.recordEntryWithExecutor(
            txn,
            CustomerLedgerEntry(
              id: 0,
              customerId: invoiceCustomerId,
              transactionType: CustomerLedgerTransactionType.salesReturn,
              amount: debtReduction,
              transactionDate: salesReturn.returnDate,
              referenceType: 'sales_return',
              referenceId: returnId,
              notes: 'تخفيض دين بموجب مرتجع مبيعات رقم $returnNumber',
              createdAt: now,
            ),
          );

          // تحديث متبقي فاتورة المبيعات
          await txn.update(
            DatabaseConstants.tableSalesInvoices,
            {
              'remaining_amount': invoiceRemaining - debtReduction,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [salesReturn.salesInvoiceId],
          );
        }

        // 7. تجهيز حركة الصندوق إن وجد استرداد نقدي (Cash Out Integration Point)
        if (refundCash > 0) {
          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashOut,
              source: FinancialFlowSource.salesReturnRefund,
              amount: refundCash,
              referenceType: 'sales_return',
              referenceId: returnId,
              description: 'صرف استرداد نقدي لمرتجع مبيعات رقم $returnNumber',
              date: salesReturn.returnDate,
            ),
          );
        }

        final saved = salesReturn.copyWith(
          id: returnId,
          returnNumber: returnNumber,
          total: totalReturnAmount,
          refundAmount: refundCash,
          debtReductionAmount: debtReduction,
          status: 'completed',
          items: savedItems,
          createdAt: now,
        );

        AppDataNotifier.instance.notifyInventoryChanged();
        AppDataNotifier.instance.notifySalesChanged();
        if (debtReduction > 0) {
          AppDataNotifier.instance.notifyCustomersChanged();
        }

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء مرتجع المبيعات في قاعدة البيانات: $e', e);
    }
  }

  Future<List<SalesReturnAvailableItem>> _getAvailableItemsWithExecutor(
      DatabaseExecutor executor, int salesInvoiceId) async {
    final sql = '''
      SELECT 
        sii.product_id,
        p.name AS product_name,
        sii.quantity AS original_qty,
        sii.unit_price,
        sii.unit_cost_at_sale,
        COALESCE((
          SELECT SUM(sri.quantity)
          FROM ${DatabaseConstants.tableSalesReturnItems} sri
          JOIN ${DatabaseConstants.tableSalesReturns} sr ON sri.sales_return_id = sr.id
          WHERE sr.sales_invoice_id = sii.sales_invoice_id 
            AND sri.product_id = sii.product_id
            AND sr.status = 'completed'
        ), 0.0) AS returned_qty
      FROM ${DatabaseConstants.tableSalesInvoiceItems} sii
      JOIN ${DatabaseConstants.tableProducts} p ON sii.product_id = p.id
      WHERE sii.sales_invoice_id = ?
    ''';

    final results = await executor.rawQuery(sql, [salesInvoiceId]);

    return results.map((row) {
      final original = (row['original_qty'] as num).toDouble();
      final returned = (row['returned_qty'] as num).toDouble();
      final available = (original - returned).clamp(0.0, original);

      return SalesReturnAvailableItem(
        productId: (row['product_id'] as num).toInt(),
        productName: row['product_name'] as String,
        originalQuantity: original,
        alreadyReturnedQuantity: returned,
        availableQuantity: available,
        unitPrice: (row['unit_price'] as num).toInt(),
        unitCostAtSale: (row['unit_cost_at_sale'] as num).toDouble(),
      );
    }).toList();
  }
}
