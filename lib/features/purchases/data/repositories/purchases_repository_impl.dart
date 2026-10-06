import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/domain/services/financial_flow_integration.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/features/products/data/repositories/stock_movements_repository_impl.dart';
import 'package:sales/features/products/domain/entities/stock_movement.dart';
import 'package:sales/features/suppliers/data/repositories/supplier_ledger_repository_impl.dart';
import 'package:sales/features/suppliers/domain/entities/supplier_ledger_entry.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_item.dart';
import '../../domain/entities/purchase_invoice_status.dart';
import '../../domain/entities/purchase_payment_type.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../../domain/services/purchase_calculation_service.dart';
import '../../domain/services/weighted_average_cost_calculator.dart';
import '../models/purchase_invoice_item_model.dart';
import '../models/purchase_invoice_model.dart';

/// تطبيق مستودع المشتريات باستخدام SQLite مع المعاملات الذرية والتكامل المحكم مع المخزون
class PurchasesRepositoryImpl implements PurchasesRepository {
  final DatabaseService _databaseService;
  final StockMovementsRepositoryImpl _stockMovementsRepository;
  final SupplierLedgerRepositoryImpl _supplierLedgerRepository;
  final FinancialFlowIntegrationService _financialService;

  PurchasesRepositoryImpl({
    DatabaseService? databaseService,
    StockMovementsRepositoryImpl? stockMovementsRepository,
    SupplierLedgerRepositoryImpl? supplierLedgerRepository,
    FinancialFlowIntegrationService? financialService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _stockMovementsRepository = stockMovementsRepository ??
            StockMovementsRepositoryImpl(
                databaseService: databaseService ?? DatabaseService.instance),
        _supplierLedgerRepository = supplierLedgerRepository ??
            SupplierLedgerRepositoryImpl(
                dbService: databaseService ?? DatabaseService.instance),
        _financialService =
            financialService ?? FinancialFlowIntegrationService.instance;

  @override
  Future<String> generateNextInvoiceNumber() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery(
        'SELECT id FROM ${DatabaseConstants.tablePurchaseInvoices} ORDER BY id DESC LIMIT 1',
      );

      final nextId = (results.isNotEmpty ? (results.first['id'] as int) : 0) + 1;
      return 'PUR-${nextId.toString().padLeft(6, '0')}';
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل توليد الرقم التسلسلي للفاتورة', e);
    }
  }

  @override
  Future<List<PurchaseInvoice>> getInvoices({
    String? searchQuery,
    int? supplierId,
    PurchasePaymentType? paymentType,
    PurchaseInvoiceStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _databaseService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClauses.add('(pi.invoice_number LIKE ? OR s.name LIKE ?)');
        final q = '%${searchQuery.trim()}%';
        whereArgs.add(q);
        whereArgs.add(q);
      }

      if (supplierId != null && supplierId > 0) {
        whereClauses.add('pi.supplier_id = ?');
        whereArgs.add(supplierId);
      }

      if (paymentType != null) {
        whereClauses.add('pi.payment_type = ?');
        whereArgs.add(paymentType.name);
      }

      if (status != null) {
        whereClauses.add('pi.status = ?');
        whereArgs.add(status.name);
      }

      if (fromDate != null) {
        whereClauses.add('pi.invoice_date >= ?');
        whereArgs.add(fromDate.toIso8601String().substring(0, 10));
      }

      if (toDate != null) {
        whereClauses.add('pi.invoice_date <= ?');
        whereArgs.add('${toDate.toIso8601String().substring(0, 10)}T23:59:59');
      }

      final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final query = '''
        SELECT 
          pi.*,
          s.name AS supplier_name,
          s.phone AS supplier_phone
        FROM ${DatabaseConstants.tablePurchaseInvoices} pi
        LEFT JOIN ${DatabaseConstants.tableSuppliers} s ON pi.supplier_id = s.id
        $whereString
        ORDER BY pi.invoice_date DESC, pi.id DESC
      ''';

      final results = await db.rawQuery(query, whereArgs);

      return results.map((map) {
        final model = PurchaseInvoiceModel.fromMap(map);
        return model.toEntity();
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة فواتير الشراء', e);
    }
  }

  @override
  Future<PurchaseInvoice> getInvoiceById(int id) async {
    try {
      final db = await _databaseService.database;

      // 1. جلب رأس الفاتورة مع بيانات المورد
      final headerQuery = '''
        SELECT 
          pi.*,
          s.name AS supplier_name,
          s.phone AS supplier_phone
        FROM ${DatabaseConstants.tablePurchaseInvoices} pi
        LEFT JOIN ${DatabaseConstants.tableSuppliers} s ON pi.supplier_id = s.id
        WHERE pi.id = ?
        LIMIT 1
      ''';

      final headerResults = await db.rawQuery(headerQuery, [id]);
      if (headerResults.isEmpty) {
        throw const NotFoundException('فاتورة الشراء المطلوبة غير موجودة في النظام');
      }

      // 2. جلب بنود وتفاصيل الفاتورة مع أسماء المنتجات والوحدات
      final itemsQuery = '''
        SELECT 
          pii.*,
          p.name AS product_name,
          u.symbol AS unit_symbol
        FROM ${DatabaseConstants.tablePurchaseInvoiceItems} pii
        LEFT JOIN ${DatabaseConstants.tableProducts} p ON pii.product_id = p.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        WHERE pii.purchase_invoice_id = ?
        ORDER BY pii.id ASC
      ''';

      final itemsResults = await db.rawQuery(itemsQuery, [id]);
      final items = itemsResults
          .map((map) => PurchaseInvoiceItemModel.fromMap(map).toEntity())
          .toList();

      final headerModel = PurchaseInvoiceModel.fromMap(headerResults.first);
      return headerModel.toEntity(items);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تفاصيل فاتورة الشراء', e);
    }
  }

  @override
  Future<PurchaseInvoice> createPurchaseInvoice({
    required PurchaseInvoice invoice,
    required List<PurchaseInvoiceItem> items,
  }) async {
    // 1. التحقق من صحة المدخلات الأساسية
    final trimmedInvoiceNumber = invoice.invoiceNumber.trim();
    if (trimmedInvoiceNumber.isEmpty) {
      throw const ValidationException('رقم فاتورة الشراء مطلوب');
    }
    if (invoice.supplierId <= 0) {
      throw const ValidationException('يرجى اختيار مورد صالح للفاتورة');
    }
    if (items.isEmpty) {
      throw const ValidationException('يجب أن تحتوي فاتورة الشراء على صنف واحد على الأقل');
    }

    // التحقق من بنود الفاتورة وحساب الإجماليات بدقة
    final calculatedItems = <PurchaseInvoiceItem>[];
    for (final item in items) {
      if (item.productId <= 0) {
        throw const ValidationException('أحد الأصناف المحددة غير صالح');
      }
      if (item.quantity <= 0) {
        throw const ValidationException('كمية الصنف يجب أن تكون أكبر من الصفر');
      }
      if (item.unitCost < 0) {
        throw const ValidationException('سعر شراء الصنف لا يمكن أن يكون سالباً');
      }

      final lineTotal = PurchaseCalculationService.calculateItemTotal(
        item.quantity,
        item.unitCost,
      );
      calculatedItems.add(item.copyWith(total: lineTotal));
    }

    final calculatedSubtotal = PurchaseCalculationService.calculateSubtotal(
      calculatedItems.map((e) => e.total),
    );
    final calculatedTotal = PurchaseCalculationService.calculateTotal(
      calculatedSubtotal,
      invoice.discount,
    );
    final calculatedRemaining = PurchaseCalculationService.calculateRemaining(
      calculatedTotal,
      invoice.paidAmount,
    );

    try {
      final db = await _databaseService.database;

      // 2. تنفيذ العملية بالكامل داخل Transaction ذرية ومحكمة (Atomicity)
      return await db.transaction<PurchaseInvoice>((txn) async {
        final now = DateTime.now().toIso8601String();

        // أ) التحقق من وجود المورد وأنه نشط
        final supplierRows = await txn.query(
          DatabaseConstants.tableSuppliers,
          where: 'id = ?',
          whereArgs: [invoice.supplierId],
          limit: 1,
        );

        if (supplierRows.isEmpty) {
          throw const NotFoundException('المورد المحدد غير مسجل في النظام');
        }

        final supplier = supplierRows.first;
        if ((supplier['is_active'] as int) == 0) {
          throw const ValidationException('لا يمكن إنشاء فاتورة لمورد معطل');
        }

        // ب) التحقق من عدم تكرار رقم الفاتورة
        final existingInvoice = await txn.query(
          DatabaseConstants.tablePurchaseInvoices,
          where: 'invoice_number = ?',
          whereArgs: [trimmedInvoiceNumber],
          limit: 1,
        );

        if (existingInvoice.isNotEmpty) {
          throw ValidationException(
            'رقم الفاتورة "$trimmedInvoiceNumber" مسجل مسبقاً، يرجى استخدام رقم فريد.',
          );
        }

        // ج) إدراج رأس الفاتورة
        final invoiceModel = PurchaseInvoiceModel(
          id: 0,
          invoiceNumber: trimmedInvoiceNumber,
          supplierId: invoice.supplierId,
          invoiceDate: invoice.invoiceDate.toIso8601String(),
          subtotal: calculatedSubtotal,
          discount: invoice.discount,
          total: calculatedTotal,
          paidAmount: invoice.paidAmount,
          remainingAmount: calculatedRemaining,
          paymentType: invoice.paymentType.name,
          status: PurchaseInvoiceStatus.completed.name,
          notes: invoice.notes?.trim(),
          createdAt: now,
          updatedAt: now,
        );

        final invoiceId = await txn.insert(
          DatabaseConstants.tablePurchaseInvoices,
          invoiceModel.toMap(),
        );

        final savedItems = <PurchaseInvoiceItem>[];

        // د) معالجة كل بند: الحفظ + تحديث المخزون + حساب المتوسط المرجح + تسجيل Stock Movement
        for (final item in calculatedItems) {
          // جلب بيانات المنتج الحالية داخل نفس المعاملة
          final productRows = await txn.query(
            DatabaseConstants.tableProducts,
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );

          if (productRows.isEmpty) {
            throw NotFoundException('المنتج برقم (${item.productId}) غير موجود');
          }

          final productData = productRows.first;
          final double oldStock = (productData['current_stock'] as num).toDouble();
          final double oldAverageCost = (productData['average_cost'] as num?)?.toDouble() ??
              (productData['purchase_price'] as num).toDouble();

          // حساب المتوسط المرجح الجديد لتكلفة المخزون
          final double newAverageCost = WeightedAverageCostCalculator.calculate(
            oldQuantity: oldStock,
            oldAverageCost: oldAverageCost,
            newQuantity: item.quantity,
            newUnitCost: item.unitCost,
          );

          // تحديث سعر الشراء الأخير ومتوسط التكلفة
          await txn.update(
            DatabaseConstants.tableProducts,
            {
              'purchase_price': item.unitCost,
              'average_cost': newAverageCost,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          // حفظ سطر الفاتورة
          final itemModel = PurchaseInvoiceItemModel(
            id: 0,
            purchaseInvoiceId: invoiceId,
            productId: item.productId,
            quantity: item.quantity,
            unitCost: item.unitCost,
            total: item.total,
          );

          final itemId = await txn.insert(
            DatabaseConstants.tablePurchaseInvoiceItems,
            itemModel.toMap(),
          );

          // زيادة رصيد المخزون وتسجيل حركة الشراء عبر الدالة المركزية
          await _stockMovementsRepository.recordMovementWithExecutor(
            txn,
            productId: item.productId,
            type: StockMovementType.purchase,
            quantity: item.quantity,
            reason: 'فاتورة شراء رقم $trimmedInvoiceNumber',
            reference: trimmedInvoiceNumber,
            notes: invoice.notes,
          );

          savedItems.add(item.copyWith(
            id: itemId,
            purchaseInvoiceId: invoiceId,
          ));
        }

        // هـ) إذا كان هناك مبلغ متبقي (شراء آجل أو جزئي)، يتم تسجيل الحركة في أستاذ المورد وتحديث رصيد دين المورد
        if (calculatedRemaining > 0) {
          final int currentBalance = (supplier['current_balance'] as num?)?.toInt() ?? 0;
          final int updatedBalance = currentBalance + calculatedRemaining;

          await _supplierLedgerRepository.recordEntryWithExecutor(
            txn,
            SupplierLedgerEntry(
              id: 0,
              supplierId: invoice.supplierId,
              transactionType: SupplierLedgerTransactionType.purchaseCredit,
              amount: calculatedRemaining,
              transactionDate: invoice.invoiceDate,
              referenceType: 'purchase_invoice',
              referenceId: invoiceId,
              notes: 'فاتورة مشتريات آجلة رقم $trimmedInvoiceNumber',
              createdAt: DateTime.parse(now),
            ),
          );

          await txn.update(
            DatabaseConstants.tableSuppliers,
            {
              'current_balance': updatedBalance,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [invoice.supplierId],
          );
        }

        // و) تجهيز التدفق المالي للصندوق (Cash Out Integration Point) للمبلغ المدفوع نقداً
        if (invoice.paidAmount > 0) {
          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashOut,
              source: FinancialFlowSource.supplierPayment,
              amount: invoice.paidAmount,
              referenceType: 'purchase_invoice',
              referenceId: invoiceId,
              description: 'سداد نقدي لفاتورة مشتريات رقم $trimmedInvoiceNumber للمورد ${supplier['name']}',
              date: invoice.invoiceDate,
            ),
          );
        }

        final saved = invoice.copyWith(
          id: invoiceId,
          invoiceNumber: trimmedInvoiceNumber,
          subtotal: calculatedSubtotal,
          total: calculatedTotal,
          remainingAmount: calculatedRemaining,
          status: PurchaseInvoiceStatus.completed,
          items: savedItems,
          createdAt: DateTime.parse(now),
          updatedAt: DateTime.parse(now),
          supplierName: supplier['name'] as String?,
          supplierPhone: supplier['phone'] as String?,
        );

        AppDataNotifier.instance.notifyInventoryChanged();
        AppDataNotifier.instance.notifyPurchasesChanged();
        if (calculatedRemaining > 0) {
          AppDataNotifier.instance.notifySuppliersChanged();
        }

        return saved;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حفظ فاتورة الشراء وتحديث المخزون', e);
    }
  }

  @override
  Future<void> cancelPurchaseInvoice(int invoiceId, {required String reason}) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const ValidationException('سبب إلغاء فاتورة الشراء مطلوب لتوثيق السجل');
    }

    try {
      final db = await _databaseService.database;

      await db.transaction((txn) async {
        // 1. جلب الفاتورة مع بنودها
        final invoiceRows = await txn.query(
          DatabaseConstants.tablePurchaseInvoices,
          where: 'id = ?',
          whereArgs: [invoiceId],
          limit: 1,
        );

        if (invoiceRows.isEmpty) {
          throw const NotFoundException('فاتورة الشراء المطلوب إلغاؤها غير موجودة');
        }

        final invoiceData = invoiceRows.first;
        final currentStatus = invoiceData['status'] as String;
        if (currentStatus == PurchaseInvoiceStatus.cancelled.name) {
          throw const ValidationException('هذه الفاتورة ملغاة بالفعل مسبقاً');
        }

        final invoiceNumber = invoiceData['invoice_number'] as String;
        final supplierId = invoiceData['supplier_id'] as int;
        final remainingAmount = (invoiceData['remaining_amount'] as num).toInt();
        final paidAmount = (invoiceData['paid_amount'] as num).toInt();

        // 2. جلب بنود الفاتورة
        final itemRows = await txn.query(
          DatabaseConstants.tablePurchaseInvoiceItems,
          where: 'purchase_invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // 3. التحقق الصارم من كفاية المخزون الحالي لإلغاء الشراء (منع المخزون السالب)
        for (final item in itemRows) {
          final productId = item['product_id'] as int;
          final double returnQty = (item['quantity'] as num).toDouble();

          final productRows = await txn.query(
            DatabaseConstants.tableProducts,
            columns: ['id', 'name', 'current_stock'],
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );

          if (productRows.isNotEmpty) {
            final p = productRows.first;
            final double currentStock = (p['current_stock'] as num).toDouble();
            final String productName = p['name'] as String;

            if (currentStock < returnQty) {
              throw ValidationException(
                'لا يمكن إلغاء الفاتورة: رصيد المخزون الحالي للمنتج "$productName" هو ($currentStock) والكمية المراد خصمها هي ($returnQty). قد تكون بعض الكميات قد تم بيعها أو تسويتها، مما يؤدي لرصيد سالب.',
              );
            }
          }
        }

        // 4. خصم الكميات من المخزون وتسجيل حركة عكسية purchaseReturn
        for (final item in itemRows) {
          final productId = item['product_id'] as int;
          final double returnQty = (item['quantity'] as num).toDouble();

          await _stockMovementsRepository.recordMovementWithExecutor(
            txn,
            productId: productId,
            type: StockMovementType.purchaseReturn,
            quantity: returnQty,
            reason: 'إلغاء فاتورة الشراء رقم $invoiceNumber: $trimmedReason',
            reference: invoiceNumber,
            notes: trimmedReason,
          );
        }

        final now = DateTime.now().toIso8601String();

        // 5. عكس أثر المتبقي على دين المورد وتسجيل حركة في أستاذ المورد
        if (remainingAmount > 0) {
          await _supplierLedgerRepository.recordEntryWithExecutor(
            txn,
            SupplierLedgerEntry(
              id: 0,
              supplierId: supplierId,
              transactionType: SupplierLedgerTransactionType.cancellation,
              amount: remainingAmount,
              transactionDate: DateTime.parse(now),
              referenceType: 'purchase_invoice',
              referenceId: invoiceId,
              notes: 'إلغاء أثر الدين لفاتورة المشتريات رقم $invoiceNumber ($trimmedReason)',
              createdAt: DateTime.parse(now),
            ),
          );

          final supplierRows = await txn.query(
            DatabaseConstants.tableSuppliers,
            columns: ['id', 'current_balance'],
            where: 'id = ?',
            whereArgs: [supplierId],
            limit: 1,
          );

          if (supplierRows.isNotEmpty) {
            final currentBalance = (supplierRows.first['current_balance'] as num).toInt();
            final updatedBalance = currentBalance - remainingAmount;

            await txn.update(
              DatabaseConstants.tableSuppliers,
              {
                'current_balance': updatedBalance,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [supplierId],
            );
          }
        }

        // 6. تجهيز استرداد نقدي إن كان تم سداد مبلغ للمورد (Cash In Integration Point)
        if (paidAmount > 0) {
          _financialService.dispatchFlow(
            FinancialFlowRecord(
              type: FinancialFlowType.cashIn,
              source: FinancialFlowSource.purchaseReturnRefund,
              amount: paidAmount,
              referenceType: 'purchase_invoice_cancellation',
              referenceId: invoiceId,
              description: 'استرداد نقدي إثر إلغاء فاتورة مشتريات رقم $invoiceNumber',
              date: DateTime.parse(now),
            ),
          );
        }

        // 7. تحديث حالة الفاتورة لـ cancelled وتصفير المتبقي
        await txn.update(
          DatabaseConstants.tablePurchaseInvoices,
          {
            'status': PurchaseInvoiceStatus.cancelled.name,
            'remaining_amount': 0,
            'notes': invoiceData['notes'] != null
                ? '${invoiceData['notes']} | تم الإلغاء: $trimmedReason'
                : 'تم الإلغاء: $trimmedReason',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        AppDataNotifier.instance.notifyInventoryChanged();
        AppDataNotifier.instance.notifyPurchasesChanged();
        AppDataNotifier.instance.notifySuppliersChanged();
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إلغاء فاتورة الشراء', e);
    }
  }
}
