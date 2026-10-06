import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../../core/domain/services/financial_flow_integration.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../products/data/repositories/stock_movements_repository_impl.dart';
import '../../../products/domain/entities/stock_movement.dart';
import '../../../suppliers/data/repositories/supplier_ledger_repository_impl.dart';
import '../../../suppliers/domain/entities/supplier_ledger_entry.dart';
import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';
import '../../domain/repositories/purchase_returns_repository.dart';
import '../models/purchase_return_item_model.dart';
import '../models/purchase_return_model.dart';

class PurchaseReturnsRepositoryImpl implements PurchaseReturnsRepository {
  final DatabaseService _dbService;
  final StockMovementsRepositoryImpl _stockMovementsRepo;
  final SupplierLedgerRepositoryImpl _supplierLedgerRepo;
  final FinancialFlowIntegrationService _financialService;

  PurchaseReturnsRepositoryImpl({
    DatabaseService? dbService,
    StockMovementsRepositoryImpl? stockMovementsRepo,
    SupplierLedgerRepositoryImpl? supplierLedgerRepo,
    FinancialFlowIntegrationService? financialService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _stockMovementsRepo = stockMovementsRepo ??
            StockMovementsRepositoryImpl(
                databaseService: dbService ?? DatabaseService.instance),
        _supplierLedgerRepo = supplierLedgerRepo ??
            SupplierLedgerRepositoryImpl(
                dbService: dbService ?? DatabaseService.instance),
        _financialService =
            financialService ?? FinancialFlowIntegrationService.instance;

  @override
  Future<String> generateNextReturnNumber([DatabaseExecutor? executor]) async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'PRET-$datePrefix-';

    try {
      final db = executor ?? await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT return_number FROM ${DatabaseConstants.tablePurchaseReturns}
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
  Future<List<PurchaseReturn>> getReturns({int? invoiceId, int? supplierId}) async {
    try {
      final db = await _dbService.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (invoiceId != null) {
        whereClauses.add('pr.purchase_invoice_id = ?');
        whereArgs.add(invoiceId);
      }

      if (supplierId != null) {
        whereClauses.add('pr.supplier_id = ?');
        whereArgs.add(supplierId);
      }

      final whereString =
          whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = '''
        SELECT 
          pr.*,
          pi.invoice_number,
          s.name AS supplier_name
        FROM ${DatabaseConstants.tablePurchaseReturns} pr
        JOIN ${DatabaseConstants.tablePurchaseInvoices} pi ON pr.purchase_invoice_id = pi.id
        JOIN ${DatabaseConstants.tableSuppliers} s ON pr.supplier_id = s.id
        $whereString
        ORDER BY pr.return_date DESC, pr.id DESC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      return results.map((row) => PurchaseReturnModel.fromMap(row).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل مرتجعات المشتريات', e);
    }
  }

  @override
  Future<PurchaseReturn> getReturnById(int id) async {
    try {
      final db = await _dbService.database;
      final sql = '''
        SELECT 
          pr.*,
          pi.invoice_number,
          s.name AS supplier_name
        FROM ${DatabaseConstants.tablePurchaseReturns} pr
        JOIN ${DatabaseConstants.tablePurchaseInvoices} pi ON pr.purchase_invoice_id = pi.id
        JOIN ${DatabaseConstants.tableSuppliers} s ON pr.supplier_id = s.id
        WHERE pr.id = ?
        LIMIT 1
      ''';

      final results = await db.rawQuery(sql, [id]);
      if (results.isEmpty) {
        throw const NotFoundException('مرتجع المشتريات المطلوب غير موجود');
      }

      final returnEntity = PurchaseReturnModel.fromMap(results.first).toEntity();

      // جلب البنود
      final itemsSql = '''
        SELECT 
          pri.*,
          p.name AS product_name
        FROM ${DatabaseConstants.tablePurchaseReturnItems} pri
        JOIN ${DatabaseConstants.tableProducts} p ON pri.product_id = p.id
        WHERE pri.purchase_return_id = ?
      ''';
      final itemRows = await db.rawQuery(itemsSql, [id]);
      final items =
          itemRows.map((r) => PurchaseReturnItemModel.fromMap(r).toEntity()).toList();

      return returnEntity.copyWith(items: items);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تفاصيل مرتجع المشتريات', e);
    }
  }

  @override
  Future<List<PurchaseReturnAvailableItem>> getAvailableReturnItems(
      int purchaseInvoiceId) async {
    try {
      final db = await _dbService.database;

      final sql = '''
        SELECT 
          pii.product_id,
          p.name AS product_name,
          p.current_stock AS warehouse_stock,
          pii.quantity AS original_qty,
          pii.unit_cost,
          COALESCE((
            SELECT SUM(pri.quantity)
            FROM ${DatabaseConstants.tablePurchaseReturnItems} pri
            JOIN ${DatabaseConstants.tablePurchaseReturns} pr ON pri.purchase_return_id = pr.id
            WHERE pr.purchase_invoice_id = pii.purchase_invoice_id 
              AND pri.product_id = pii.product_id
              AND pr.status = 'completed'
          ), 0.0) AS returned_qty
        FROM ${DatabaseConstants.tablePurchaseInvoiceItems} pii
        JOIN ${DatabaseConstants.tableProducts} p ON pii.product_id = p.id
        WHERE pii.purchase_invoice_id = ?
      ''';

      final results = await db.rawQuery(sql, [purchaseInvoiceId]);

      return results.map((row) {
        final original = (row['original_qty'] as num).toDouble();
        final returned = (row['returned_qty'] as num).toDouble();
        final available = (original - returned).clamp(0.0, original);
        final warehouseStock = (row['warehouse_stock'] as num).toDouble();

        return PurchaseReturnAvailableItem(
          productId: (row['product_id'] as num).toInt(),
          productName: row['product_name'] as String,
          originalQuantity: original,
          alreadyReturnedQuantity: returned,
          availableQuantity: available,
          currentWarehouseStock: warehouseStock,
          unitCost: (row['unit_cost'] as num).toInt(),
        );
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بنود الشراء المتاحة للإرجاع', e);
    }
  }

  @override
  Future<PurchaseReturn> createReturn(PurchaseReturn purchaseReturn) async {
    if (purchaseReturn.items.isEmpty) {
      throw const ValidationException('يجب تحديد صنف واحد على الأقل للإرجاع');
    }

    try {
      final db = await _dbService.database;

      return await db.transaction<PurchaseReturn>((txn) async {
        // 1. التحقق من وجود فاتورة الشراء الأصلية وأنها مكتملة
        final invoiceRows = await txn.query(
          DatabaseConstants.tablePurchaseInvoices,
          where: 'id = ?',
          whereArgs: [purchaseReturn.purchaseInvoiceId],
          limit: 1,
        );

        if (invoiceRows.isEmpty) {
          throw const NotFoundException('فاتورة المشتريات الأصلية غير موجودة');
        }

        final invoice = invoiceRows.first;
        final invoiceStatus = invoice['status'] as String;
        if (invoiceStatus != 'completed') {
          throw const ValidationException(
              'لا يمكن إنشاء مرتجع لفاتورة مشتريات ملغاة أو غير مكتملة');
        }

        final invoiceNumber = invoice['invoice_number'] as String;
        final supplierId = invoice['supplier_id'] as int;
        final invoiceRemaining = (invoice['remaining_amount'] as num).toInt();

        // 2. التحقق من المتاح للإرجاع والمخزون الفعلي بالمستودع
        final availableItems =
            await _getAvailableItemsWithExecutor(txn, purchaseReturn.purchaseInvoiceId);
        final availableMap = {for (var a in availableItems) a.productId: a};

        int totalReturnAmount = 0;
        final verifiedItems = <PurchaseReturnItem>[];

        for (final item in purchaseReturn.items) {
          if (item.quantity <= 0) continue;

          final available = availableMap[item.productId];
          if (available == null) {
            throw ValidationException(
                'المنتج رقم (${item.productId}) لم يكن ضمن فاتورة المشتريات الأصلية');
          }

          if (item.quantity > available.availableQuantity) {
            throw ValidationException(
              'الكمية المراد إرجاعها للمنتج "${available.productName}" هي (${item.quantity}) وتتجاوز الكمية المتاحة للإرجاع من الفاتورة (${available.availableQuantity}).',
            );
          }

          // فحص المخزون الفعلي الحالي بالمستودع لمنع المخزون السالب
          final prodRows = await txn.query(
            DatabaseConstants.tableProducts,
            columns: ['id', 'name', 'current_stock'],
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          final currentStock = (prodRows.first['current_stock'] as num).toDouble();
          if (currentStock < item.quantity) {
            throw ValidationException(
              'لا يمكن إرجاع (${item.quantity}) من المنتج "${available.productName}" لأن الرصيد المتوفر فعلياً في المستودع حالياً هو ($currentStock) فقط.',
            );
          }

          final lineTotal = (item.quantity * available.unitCost).round();
          totalReturnAmount += lineTotal;

          verifiedItems.add(item.copyWith(
            productName: available.productName,
            unitCost: available.unitCost,
            total: lineTotal,
          ));
        }

        if (verifiedItems.isEmpty) {
          throw const ValidationException('يجب إدخال كمية إرجاع أكبر من الصفر');
        }

        final returnNumber = purchaseReturn.returnNumber.trim().isNotEmpty
            ? purchaseReturn.returnNumber.trim()
            : await generateNextReturnNumber(txn);

        // فحص تكرار رقم المرتجع
        final existingRet = await txn.query(
          DatabaseConstants.tablePurchaseReturns,
          where: 'return_number = ?',
          whereArgs: [returnNumber],
        );
        if (existingRet.isNotEmpty) {
          throw ValidationException('رقم المرتجع "$returnNumber" مسجل مسبقاً');
        }

        // 3. احتساب الأثر المالي (تخفيض دين المورد أو استرداد نقدي من المورد)
        int debtReduction = 0;
        int refundCash = totalReturnAmount;

        final supplierDebt = await _supplierLedgerRepo
            .getSupplierBalanceWithExecutor(txn, supplierId);

        final maxAllowedDebtReduction =
            supplierDebt < invoiceRemaining ? supplierDebt : invoiceRemaining;

        if (maxAllowedDebtReduction > 0) {
          debtReduction = totalReturnAmount <= maxAllowedDebtReduction
              ? totalReturnAmount
              : maxAllowedDebtReduction;
          refundCash = totalReturnAmount - debtReduction;
        } else {
          debtReduction = 0;
          refundCash = totalReturnAmount;
        }

        final now = DateTime.now();

        // 4. إدراج رأس المرتجع
        final returnModel = PurchaseReturnModel(
          id: 0,
          returnNumber: returnNumber,
          purchaseInvoiceId: purchaseReturn.purchaseInvoiceId,
          purchaseInvoiceNumber: invoiceNumber,
          supplierId: supplierId,
          returnDate: purchaseReturn.returnDate.toIso8601String(),
          total: totalReturnAmount,
          refundAmount: refundCash,
          debtReductionAmount: debtReduction,
          status: 'completed',
          notes: purchaseReturn.notes?.trim(),
          createdAt: now.toIso8601String(),
        );

        final returnId = await txn.insert(
          DatabaseConstants.tablePurchaseReturns,
          returnModel.toMap(),
        );

        // 5. إدراج البنود وخصم المخزون وتسجيل حركات المخزون
        final savedItems = <PurchaseReturnItem>[];
        for (final item in verifiedItems) {
          final itemModel = PurchaseReturnItemModel.fromEntity(
            item.copyWith(purchaseReturnId: returnId),
          );

          final itemId = await txn.insert(
            DatabaseConstants.tablePurchaseReturnItems,
            itemModel.toMap(),
          );

          savedItems.add(item.copyWith(id: itemId, purchaseReturnId: returnId));

          // خصم المخزون عبر الدالة المركزية بحركة purchaseReturn
          await _stockMovementsRepo.recordMovementWithExecutor(
            txn,
            productId: item.productId,
            type: StockMovementType.purchaseReturn,
            quantity: item.quantity,
            reason: 'مرتجع مشتريات رقم $returnNumber لفاتورة $invoiceNumber',
            reference: returnNumber,
            notes: 'إرجاع لمورد بسعر شراء ${item.unitCost}',
          );
        }

        // 6. تسجيل الأثر المالي في أستاذ المورد إن وجد تخفيض دين
        if (debtReduction > 0) {
          await _supplierLedgerRepo.recordEntryWithExecutor(
            txn,
            SupplierLedgerEntry(
              id: 0,
              supplierId: supplierId,
              transactionType: SupplierLedgerTransactionType.purchaseReturn,
              amount: debtReduction,
              transactionDate: purchaseReturn.returnDate,
              referenceType: 'purchase_return',
              referenceId: returnId,
              notes: 'تخفيض دين بموجب مرتجع مشتريات رقم $returnNumber',
              createdAt: now,
            ),
          );

          // تحديث متبقي فاتورة المشتريات ورصيد المورد
          await txn.update(
            DatabaseConstants.tablePurchaseInvoices,
            {
              'remaining_amount': invoiceRemaining - debtReduction,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [purchaseReturn.purchaseInvoiceId],
          );

          await txn.update(
            DatabaseConstants.tableSuppliers,
            {
              'current_balance': supplierDebt - debtReduction,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [supplierId],
          );
        }

        // 7. تجهيز حركة الصندوق إن وجد استرداد نقدي من المورد (Cash In Integration Point)
        if (refundCash > 0) {
          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashIn,
              source: FinancialFlowSource.purchaseReturnRefund,
              amount: refundCash,
              referenceType: 'purchase_return',
              referenceId: returnId,
              description: 'قبض استرداد نقدي من مورد لمرتجع مشتريات رقم $returnNumber',
              date: purchaseReturn.returnDate,
            ),
          );
        }

        final saved = purchaseReturn.copyWith(
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
        AppDataNotifier.instance.notifyPurchasesChanged();
        if (debtReduction > 0) {
          AppDataNotifier.instance.notifySuppliersChanged();
        }

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء مرتجع المشتريات في قاعدة البيانات: $e', e);
    }
  }

  Future<List<PurchaseReturnAvailableItem>> _getAvailableItemsWithExecutor(
      DatabaseExecutor executor, int purchaseInvoiceId) async {
    final sql = '''
      SELECT 
        pii.product_id,
        p.name AS product_name,
        p.current_stock AS warehouse_stock,
        pii.quantity AS original_qty,
        pii.unit_cost,
        COALESCE((
          SELECT SUM(pri.quantity)
          FROM ${DatabaseConstants.tablePurchaseReturnItems} pri
          JOIN ${DatabaseConstants.tablePurchaseReturns} pr ON pri.purchase_return_id = pr.id
          WHERE pr.purchase_invoice_id = pii.purchase_invoice_id 
            AND pri.product_id = pii.product_id
            AND pr.status = 'completed'
        ), 0.0) AS returned_qty
      FROM ${DatabaseConstants.tablePurchaseInvoiceItems} pii
      JOIN ${DatabaseConstants.tableProducts} p ON pii.product_id = p.id
      WHERE pii.purchase_invoice_id = ?
    ''';

    final results = await executor.rawQuery(sql, [purchaseInvoiceId]);

    return results.map((row) {
      final original = (row['original_qty'] as num).toDouble();
      final returned = (row['returned_qty'] as num).toDouble();
      final available = (original - returned).clamp(0.0, original);
      final warehouseStock = (row['warehouse_stock'] as num).toDouble();

      return PurchaseReturnAvailableItem(
        productId: (row['product_id'] as num).toInt(),
        productName: row['product_name'] as String,
        originalQuantity: original,
        alreadyReturnedQuantity: returned,
        availableQuantity: available,
        currentWarehouseStock: warehouseStock,
        unitCost: (row['unit_cost'] as num).toInt(),
      );
    }).toList();
  }
}
