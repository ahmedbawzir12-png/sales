import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../domain/entities/date_range.dart';
import '../../domain/entities/debts_report_data.dart';
import '../../domain/entities/expenses_report_data.dart';
import '../../domain/entities/inventory_report_data.dart';
import '../../domain/entities/profit_loss_report_data.dart';
import '../../domain/entities/purchases_report_data.dart';
import '../../domain/entities/sales_report_data.dart';
import '../../domain/entities/stock_movement_report_row.dart';
import '../../domain/entities/yearly_report_data.dart';
import '../../domain/repositories/reports_repository.dart';

/// تطبيق مستودع التقارير الشاملة للنظام بالاعتماد المباشر على محرك SQLite (Read-Only)
class ReportsRepositoryImpl implements ReportsRepository {
  final DatabaseService _dbService;

  ReportsRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<SalesReportData> getSalesReport(DateRange range) async {
    try {
      final db = await _dbService.database;

      // 1. تجميع إجماليات فواتير المبيعات المكتملة ضمن الفترة
      final salesAgg = await db.rawQuery('''
        SELECT 
          COUNT(*) AS invoice_count,
          COALESCE(SUM(total), 0) AS gross_sales,
          COALESCE(SUM(discount), 0) AS discount_total,
          COALESCE(SUM(paid_amount), 0) AS cash_paid_total,
          COALESCE(SUM(remaining_amount), 0) AS remaining_debt_total,
          COALESCE(SUM(CASE WHEN payment_type = 'credit' THEN total ELSE 0 END), 0) AS credit_sales_total
        FROM ${DatabaseConstants.tableSalesInvoices}
        WHERE status = 'completed'
          AND invoice_date >= ? AND invoice_date < ?;
      ''', [range.startIso, range.endIso]);

      // 2. تجميع إجمالي مرتجعات المبيعات المكتملة ضمن الفترة
      final returnsAgg = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(total), 0) AS returns_total
        FROM ${DatabaseConstants.tableSalesReturns}
        WHERE status = 'completed'
          AND return_date >= ? AND return_date < ?;
      ''', [range.startIso, range.endIso]);

      // 3. استرجاع قائمة الفواتير المفصلة
      final invoiceRows = await db.rawQuery('''
        SELECT 
          si.id,
          si.invoice_number,
          si.invoice_date,
          c.name AS customer_name,
          si.total,
          si.paid_amount,
          si.remaining_amount,
          si.payment_type,
          si.status
        FROM ${DatabaseConstants.tableSalesInvoices} si
        LEFT JOIN ${DatabaseConstants.tableCustomers} c ON si.customer_id = c.id
        WHERE si.status = 'completed'
          AND si.invoice_date >= ? AND si.invoice_date < ?
        ORDER BY si.invoice_date DESC, si.id DESC;
      ''', [range.startIso, range.endIso]);

      final firstSales = salesAgg.first;
      final invoiceCount = (firstSales['invoice_count'] as num?)?.toInt() ?? 0;
      final grossSales = (firstSales['gross_sales'] as num?)?.toInt() ?? 0;
      final discountTotal = (firstSales['discount_total'] as num?)?.toInt() ?? 0;
      final cashPaidTotal = (firstSales['cash_paid_total'] as num?)?.toInt() ?? 0;
      final remainingDebtTotal = (firstSales['remaining_debt_total'] as num?)?.toInt() ?? 0;
      final creditSalesTotal = (firstSales['credit_sales_total'] as num?)?.toInt() ?? 0;
      final returnsTotal = (returnsAgg.first['returns_total'] as num?)?.toInt() ?? 0;
      final netSales = grossSales - returnsTotal;
      final avgInvoice = invoiceCount > 0 ? grossSales / invoiceCount : 0.0;

      final invoices = invoiceRows.map((row) {
        return SalesInvoiceReportRow(
          id: row['id'] as int,
          invoiceNumber: row['invoice_number'] as String,
          invoiceDate: DateTime.parse(row['invoice_date'] as String),
          customerName: row['customer_name'] as String?,
          total: (row['total'] as num).toInt(),
          paidAmount: (row['paid_amount'] as num).toInt(),
          remainingAmount: (row['remaining_amount'] as num).toInt(),
          paymentType: row['payment_type'] as String,
          status: row['status'] as String,
        );
      }).toList();

      return SalesReportData(
        dateRange: range,
        invoiceCount: invoiceCount,
        grossSales: grossSales,
        discountTotal: discountTotal,
        returnsTotal: returnsTotal,
        netSales: netSales,
        cashPaidTotal: cashPaidTotal,
        creditSalesTotal: creditSalesTotal,
        remainingDebtTotal: remainingDebtTotal,
        averageInvoiceValue: avgInvoice,
        invoices: invoices,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج تقرير المبيعات', e);
    }
  }

  @override
  Future<PurchasesReportData> getPurchasesReport(DateRange range) async {
    try {
      final db = await _dbService.database;

      // 1. تجميع إجماليات فواتير المشتريات المكتملة
      final purchasesAgg = await db.rawQuery('''
        SELECT 
          COUNT(*) AS invoice_count,
          COALESCE(SUM(total), 0) AS gross_purchases,
          COALESCE(SUM(discount), 0) AS discount_total,
          COALESCE(SUM(paid_amount), 0) AS cash_paid_total,
          COALESCE(SUM(remaining_amount), 0) AS remaining_debt_total,
          COALESCE(SUM(CASE WHEN payment_type = 'credit' THEN total ELSE 0 END), 0) AS credit_purchases_total
        FROM ${DatabaseConstants.tablePurchaseInvoices}
        WHERE status = 'completed'
          AND invoice_date >= ? AND invoice_date < ?;
      ''', [range.startIso, range.endIso]);

      // 2. تجميع إجمالي مرتجعات المشتريات
      final returnsAgg = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(total), 0) AS returns_total
        FROM ${DatabaseConstants.tablePurchaseReturns}
        WHERE status = 'completed'
          AND return_date >= ? AND return_date < ?;
      ''', [range.startIso, range.endIso]);

      // 3. استرجاع قائمة الفواتير المفصلة
      final invoiceRows = await db.rawQuery('''
        SELECT 
          pi.id,
          pi.invoice_number,
          pi.invoice_date,
          s.name AS supplier_name,
          pi.total,
          pi.paid_amount,
          pi.remaining_amount,
          pi.payment_type,
          pi.status
        FROM ${DatabaseConstants.tablePurchaseInvoices} pi
        LEFT JOIN ${DatabaseConstants.tableSuppliers} s ON pi.supplier_id = s.id
        WHERE pi.status = 'completed'
          AND pi.invoice_date >= ? AND pi.invoice_date < ?
        ORDER BY pi.invoice_date DESC, pi.id DESC;
      ''', [range.startIso, range.endIso]);

      final firstPurchase = purchasesAgg.first;
      final invoiceCount = (firstPurchase['invoice_count'] as num?)?.toInt() ?? 0;
      final grossPurchases = (firstPurchase['gross_purchases'] as num?)?.toInt() ?? 0;
      final discountTotal = (firstPurchase['discount_total'] as num?)?.toInt() ?? 0;
      final cashPaidTotal = (firstPurchase['cash_paid_total'] as num?)?.toInt() ?? 0;
      final remainingDebtTotal = (firstPurchase['remaining_debt_total'] as num?)?.toInt() ?? 0;
      final creditPurchasesTotal = (firstPurchase['credit_purchases_total'] as num?)?.toInt() ?? 0;
      final returnsTotal = (returnsAgg.first['returns_total'] as num?)?.toInt() ?? 0;
      final netPurchases = grossPurchases - returnsTotal;
      final avgInvoice = invoiceCount > 0 ? grossPurchases / invoiceCount : 0.0;

      final invoices = invoiceRows.map((row) {
        return PurchaseInvoiceReportRow(
          id: row['id'] as int,
          invoiceNumber: row['invoice_number'] as String,
          invoiceDate: DateTime.parse(row['invoice_date'] as String),
          supplierName: row['supplier_name'] as String?,
          total: (row['total'] as num).toInt(),
          paidAmount: (row['paid_amount'] as num).toInt(),
          remainingAmount: (row['remaining_amount'] as num).toInt(),
          paymentType: row['payment_type'] as String,
          status: row['status'] as String,
        );
      }).toList();

      return PurchasesReportData(
        dateRange: range,
        invoiceCount: invoiceCount,
        grossPurchases: grossPurchases,
        discountTotal: discountTotal,
        returnsTotal: returnsTotal,
        netPurchases: netPurchases,
        cashPaidTotal: cashPaidTotal,
        creditPurchasesTotal: creditPurchasesTotal,
        remainingDebtTotal: remainingDebtTotal,
        averageInvoiceValue: avgInvoice,
        invoices: invoices,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج تقرير المشتريات', e);
    }
  }

  @override
  Future<InventoryReportData> getInventoryReport() async {
    try {
      final db = await _dbService.database;

      final itemsRaw = await db.rawQuery('''
        SELECT 
          p.id,
          p.name,
          COALESCE(c.name, 'بدون تصنيف') AS category_name,
          COALESCE(u.symbol, 'قطعة') AS unit_symbol,
          p.current_stock,
          p.minimum_stock,
          p.average_cost,
          (p.current_stock * p.average_cost) AS total_cost_value,
          p.sale_price,
          CASE 
            WHEN p.current_stock <= 0 THEN 'نفد'
            WHEN p.current_stock <= p.minimum_stock THEN 'منخفض'
            ELSE 'متوفر'
          END AS stock_status
        FROM ${DatabaseConstants.tableProducts} p
        LEFT JOIN ${DatabaseConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        WHERE p.is_active = 1
        ORDER BY p.name ASC;
      ''');

      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;
      double totalQty = 0.0;
      double totalCost = 0.0;
      int totalSale = 0;

      final items = itemsRaw.map((row) {
        final currentStock = (row['current_stock'] as num).toDouble();
        final minimumStock = (row['minimum_stock'] as num).toDouble();
        final averageCost = (row['average_cost'] as num).toDouble();
        final costVal = (row['total_cost_value'] as num).toDouble();
        final salePrice = (row['sale_price'] as num).toInt();
        final status = row['stock_status'] as String;

        totalQty += currentStock;
        totalCost += costVal;
        totalSale += (currentStock * salePrice).round();

        if (currentStock <= 0) {
          outOfStock++;
        } else if (currentStock <= minimumStock) {
          lowStock++;
        } else {
          inStock++;
        }

        return InventoryReportRow(
          id: row['id'] as int,
          name: row['name'] as String,
          categoryName: row['category_name'] as String,
          unitSymbol: row['unit_symbol'] as String,
          currentStock: currentStock,
          minimumStock: minimumStock,
          averageCost: averageCost,
          totalCostValue: costVal,
          salePrice: salePrice,
          status: status,
        );
      }).toList();

      return InventoryReportData(
        totalProductsCount: items.length,
        inStockCount: inStock,
        lowStockCount: lowStock,
        outOfStockCount: outOfStock,
        totalStockQuantity: totalQty,
        totalInventoryCostValue: totalCost,
        totalInventorySaleValue: totalSale,
        items: items,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج تقرير المخزون', e);
    }
  }

  @override
  Future<List<StockMovementReportRow>> getStockMovementsReport({
    DateRange? range,
    int? productId,
  }) async {
    try {
      final db = await _dbService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (range != null) {
        whereClauses.add('sm.created_at >= ? AND sm.created_at < ?');
        whereArgs.add(range.startIso);
        whereArgs.add(range.endIso);
      }

      if (productId != null) {
        whereClauses.add('sm.product_id = ?');
        whereArgs.add(productId);
      }

      final whereString = whereClauses.isNotEmpty
          ? 'WHERE ${whereClauses.join(' AND ')}'
          : '';

      final results = await db.rawQuery('''
        SELECT 
          sm.id,
          sm.product_id,
          p.name AS product_name,
          COALESCE(c.name, 'عام') AS category_name,
          COALESCE(u.symbol, 'قطعة') AS unit_symbol,
          sm.movement_type,
          sm.quantity,
          sm.stock_before,
          sm.stock_after,
          sm.reason,
          sm.reference,
          sm.created_at
        FROM ${DatabaseConstants.tableStockMovements} sm
        JOIN ${DatabaseConstants.tableProducts} p ON sm.product_id = p.id
        LEFT JOIN ${DatabaseConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        $whereString
        ORDER BY sm.created_at DESC, sm.id DESC;
      ''', whereArgs);

      return results.map((row) {
        final rawType = row['movement_type'] as String;
        final arabicType = _mapMovementTypeToArabic(rawType);

        return StockMovementReportRow(
          id: row['id'] as int,
          productId: row['product_id'] as int,
          productName: row['product_name'] as String,
          categoryName: row['category_name'] as String,
          unitSymbol: row['unit_symbol'] as String,
          movementType: arabicType,
          quantity: (row['quantity'] as num).toDouble(),
          stockBefore: (row['stock_before'] as num).toDouble(),
          stockAfter: (row['stock_after'] as num).toDouble(),
          reason: row['reason'] as String,
          reference: row['reference'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج سجل حركة المخزون', e);
    }
  }

  String _mapMovementTypeToArabic(String rawType) {
    switch (rawType) {
      case 'initialStock':
        return 'مخزون افتتاحي';
      case 'adjustmentIncrease':
        return 'تسوية جردية (فائض)';
      case 'adjustmentDecrease':
        return 'تسوية جردية (عجز)';
      case 'purchase':
        return 'فاتورة شراء';
      case 'sale':
        return 'فاتورة مبيعات';
      case 'saleReturn':
        return 'مرتجع مبيعات';
      case 'purchaseReturn':
        return 'مرتجع مشتريات';
      default:
        return rawType;
    }
  }

  @override
  Future<DebtsReportData> getDebtsReport() async {
    try {
      final db = await _dbService.database;

      // 1. ديون العملاء
      final custRows = await db.rawQuery('''
        SELECT 
          c.id,
          c.name,
          c.phone,
          COALESCE(SUM(CASE WHEN cl.transaction_type = 'sale_credit' THEN cl.amount ELSE 0 END), 0) AS credit_sales_total,
          COALESCE(SUM(CASE WHEN cl.transaction_type = 'payment' THEN cl.amount ELSE 0 END), 0) AS paid_total,
          COALESCE(SUM(CASE WHEN cl.transaction_type IN ('sales_return', 'cancellation') THEN cl.amount ELSE 0 END), 0) AS returns_total,
          COALESCE(SUM(CASE 
            WHEN cl.transaction_type = 'sale_credit' THEN cl.amount 
            WHEN cl.transaction_type IN ('payment', 'sales_return', 'cancellation') THEN -cl.amount 
            WHEN cl.transaction_type = 'adjustment' THEN cl.amount 
            ELSE 0 
          END), 0) AS remaining_balance,
          MAX(cl.transaction_date) AS last_activity_date
        FROM ${DatabaseConstants.tableCustomers} c
        LEFT JOIN ${DatabaseConstants.tableCustomerLedger} cl ON c.id = cl.customer_id
        WHERE c.is_active = 1
        GROUP BY c.id
        HAVING remaining_balance > 0
        ORDER BY remaining_balance DESC;
      ''');

      // 2. ديون الموردين
      final suppRows = await db.rawQuery('''
        SELECT 
          s.id,
          s.name,
          s.phone,
          COALESCE(SUM(CASE WHEN sl.transaction_type = 'purchase_credit' THEN sl.amount ELSE 0 END), 0) AS credit_purchases_total,
          COALESCE(SUM(CASE WHEN sl.transaction_type = 'payment' THEN sl.amount ELSE 0 END), 0) AS paid_total,
          COALESCE(SUM(CASE WHEN sl.transaction_type IN ('purchase_return', 'cancellation') THEN sl.amount ELSE 0 END), 0) AS returns_total,
          COALESCE(SUM(CASE 
            WHEN sl.transaction_type = 'purchase_credit' THEN sl.amount 
            WHEN sl.transaction_type IN ('payment', 'purchase_return', 'cancellation') THEN -sl.amount 
            WHEN sl.transaction_type = 'adjustment' THEN sl.amount 
            ELSE 0 
          END), 0) AS remaining_balance,
          MAX(sl.transaction_date) AS last_activity_date
        FROM ${DatabaseConstants.tableSuppliers} s
        LEFT JOIN ${DatabaseConstants.tableSupplierLedger} sl ON s.id = sl.supplier_id
        WHERE s.is_active = 1
        GROUP BY s.id
        HAVING remaining_balance > 0
        ORDER BY remaining_balance DESC;
      ''');

      // 3. إجمالي ديون العملاء الإجمالية
      final totalCustRes = await db.rawQuery('''
        SELECT COALESCE(
          SUM(CASE 
            WHEN transaction_type = 'sale_credit' THEN amount 
            WHEN transaction_type IN ('payment', 'sales_return', 'cancellation') THEN -amount 
            WHEN transaction_type = 'adjustment' THEN amount 
            ELSE 0 
          END), 
          0
        ) AS total_debt
        FROM ${DatabaseConstants.tableCustomerLedger};
      ''');

      // 4. إجمالي ديون الموردين الإجمالية
      final totalSuppRes = await db.rawQuery('''
        SELECT COALESCE(
          SUM(CASE 
            WHEN transaction_type = 'purchase_credit' THEN amount 
            WHEN transaction_type IN ('payment', 'purchase_return', 'cancellation') THEN -amount 
            WHEN transaction_type = 'adjustment' THEN amount 
            ELSE 0 
          END), 
          0
        ) AS total_debt
        FROM ${DatabaseConstants.tableSupplierLedger};
      ''');

      final totalCustDebt = (totalCustRes.first['total_debt'] as num?)?.toInt() ?? 0;
      final totalSuppDebt = (totalSuppRes.first['total_debt'] as num?)?.toInt() ?? 0;

      final customerDebts = custRows.map((r) {
        return CustomerDebtReportRow(
          id: r['id'] as int,
          name: r['name'] as String,
          phone: r['phone'] as String?,
          creditSalesTotal: (r['credit_sales_total'] as num).toInt(),
          paidTotal: (r['paid_total'] as num).toInt(),
          returnsTotal: (r['returns_total'] as num).toInt(),
          remainingBalance: (r['remaining_balance'] as num).toInt(),
          lastActivityDate: r['last_activity_date'] != null
              ? DateTime.tryParse(r['last_activity_date'] as String)
              : null,
        );
      }).toList();

      final supplierDebts = suppRows.map((r) {
        return SupplierDebtReportRow(
          id: r['id'] as int,
          name: r['name'] as String,
          phone: r['phone'] as String?,
          creditPurchasesTotal: (r['credit_purchases_total'] as num).toInt(),
          paidTotal: (r['paid_total'] as num).toInt(),
          returnsTotal: (r['returns_total'] as num).toInt(),
          remainingBalance: (r['remaining_balance'] as num).toInt(),
          lastActivityDate: r['last_activity_date'] != null
              ? DateTime.tryParse(r['last_activity_date'] as String)
              : null,
        );
      }).toList();

      return DebtsReportData(
        totalCustomerDebt: totalCustDebt,
        totalSupplierDebt: totalSuppDebt,
        netDebt: totalCustDebt - totalSuppDebt,
        customerDebts: customerDebts,
        supplierDebts: supplierDebts,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج تقرير الديون والذمم', e);
    }
  }

  @override
  Future<ExpensesReportData> getExpensesReport(DateRange range) async {
    try {
      final db = await _dbService.database;

      // 1. الإجمالي الكلي للمصروفات
      final totalRes = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total_expenses
        FROM ${DatabaseConstants.tableExpenses}
        WHERE expense_date >= ? AND expense_date < ?;
      ''', [range.startIso, range.endIso]);

      final totalExpenses = (totalRes.first['total_expenses'] as num?)?.toInt() ?? 0;

      // 2. التوزيع حسب التصنيف
      final catRows = await db.rawQuery('''
        SELECT 
          category_name,
          COALESCE(SUM(amount), 0) AS cat_amount
        FROM ${DatabaseConstants.tableExpenses}
        WHERE expense_date >= ? AND expense_date < ?
        GROUP BY category_name
        ORDER BY cat_amount DESC;
      ''', [range.startIso, range.endIso]);

      final categoryBreakdown = catRows.map((r) {
        final amount = (r['cat_amount'] as num).toInt();
        final pct = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0.0;
        return ExpenseCategoryReportRow(
          categoryName: r['category_name'] as String,
          amount: amount,
          percentage: pct,
        );
      }).toList();

      // 3. سجل العمليات المفصل
      final expRows = await db.rawQuery('''
        SELECT 
          id,
          category_name,
          amount,
          expense_date,
          description,
          notes
        FROM ${DatabaseConstants.tableExpenses}
        WHERE expense_date >= ? AND expense_date < ?
        ORDER BY expense_date DESC, id DESC;
      ''', [range.startIso, range.endIso]);

      final expenses = expRows.map((r) {
        return ExpenseReportRow(
          id: r['id'] as int,
          categoryName: r['category_name'] as String,
          amount: (r['amount'] as num).toInt(),
          expenseDate: DateTime.parse(r['expense_date'] as String),
          description: r['description'] as String,
          notes: r['notes'] as String?,
        );
      }).toList();

      return ExpensesReportData(
        dateRange: range,
        totalExpenses: totalExpenses,
        categoryBreakdown: categoryBreakdown,
        expenses: expenses,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج تقرير المصروفات', e);
    }
  }

  @override
  Future<ProfitLossReportData> getProfitLossReport(DateRange range) async {
    try {
      final db = await _dbService.database;

      // 1. إجمالي المبيعات قبل المرتجعات
      final grossSalesRes = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) AS gross_sales
        FROM ${DatabaseConstants.tableSalesInvoices}
        WHERE status = 'completed'
          AND invoice_date >= ? AND invoice_date < ?;
      ''', [range.startIso, range.endIso]);
      final grossSales = (grossSalesRes.first['gross_sales'] as num?)?.toInt() ?? 0;

      // 2. إجمالي مرتجعات المبيعات
      final returnsRes = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) AS sales_returns
        FROM ${DatabaseConstants.tableSalesReturns}
        WHERE status = 'completed'
          AND return_date >= ? AND return_date < ?;
      ''', [range.startIso, range.endIso]);
      final salesReturns = (returnsRes.first['sales_returns'] as num?)?.toInt() ?? 0;

      final netSales = grossSales - salesReturns;

      // 3. تكلفة البضاعة المباعة التاريخية (Gross COGS)
      // تعتمد حصرياً على unit_cost_at_sale المحفوظة وقت البيع في جدول بنود المبيعات
      final grossCogsRes = await db.rawQuery('''
        SELECT COALESCE(SUM(sii.quantity * sii.unit_cost_at_sale), 0.0) AS gross_cogs
        FROM ${DatabaseConstants.tableSalesInvoiceItems} sii
        JOIN ${DatabaseConstants.tableSalesInvoices} si ON sii.sales_invoice_id = si.id
        WHERE si.status = 'completed'
          AND si.invoice_date >= ? AND si.invoice_date < ?;
      ''', [range.startIso, range.endIso]);
      final grossCogs = (grossCogsRes.first['gross_cogs'] as num?)?.toDouble() ?? 0.0;

      // 4. تكلفة البضاعة المسترجعة تاريخياً (Returned COGS)
      // تعتمد على unit_cost_at_sale المحفوظة في بنود مرتجع المبيعات
      final returnedCogsRes = await db.rawQuery('''
        SELECT COALESCE(SUM(sri.quantity * sri.unit_cost_at_sale), 0.0) AS returned_cogs
        FROM ${DatabaseConstants.tableSalesReturnItems} sri
        JOIN ${DatabaseConstants.tableSalesReturns} sr ON sri.sales_return_id = sr.id
        WHERE sr.status = 'completed'
          AND sr.return_date >= ? AND sr.return_date < ?;
      ''', [range.startIso, range.endIso]);
      final returnedCogs = (returnedCogsRes.first['returned_cogs'] as num?)?.toDouble() ?? 0.0;

      final netCogs = grossCogs - returnedCogs;
      final grossProfit = netSales - netCogs;

      // 5. المصروفات التشغيلية الحقيقية (Operating Expenses)
      // تستبعد سحوبات المالك ومدفوعات الموردين تلقائياً لأنها في جدول حركات الصندوق/أستاذ المورد وليست في expenses
      final expRes = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS operating_expenses
        FROM ${DatabaseConstants.tableExpenses}
        WHERE expense_date >= ? AND expense_date < ?;
      ''', [range.startIso, range.endIso]);
      final operatingExpenses = (expRes.first['operating_expenses'] as num?)?.toInt() ?? 0;

      final netProfit = grossProfit - operatingExpenses;

      return ProfitLossReportData(
        dateRange: range,
        grossSales: grossSales,
        salesReturns: salesReturns,
        netSales: netSales,
        grossCogs: grossCogs,
        returnedCogs: returnedCogs,
        netCogs: netCogs,
        grossProfit: grossProfit,
        operatingExpenses: operatingExpenses,
        netProfit: netProfit,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب تقرير الأرباح والخسائر', e);
    }
  }

  @override
  Future<YearlyReportData> getYearlyReport(int year) async {
    try {
      final monthlyBreakdown = <MonthlyProfitRow>[];

      int totalGross = 0;
      int totalReturns = 0;
      int totalNet = 0;
      double totalCogs = 0.0;
      double totalGrossProf = 0.0;
      int totalExp = 0;
      double totalNetProf = 0.0;

      const monthNames = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];

      for (int m = 1; m <= 12; m++) {
        final range = DateRange.month(year, m);
        final pl = await getProfitLossReport(range);

        totalGross += pl.grossSales;
        totalReturns += pl.salesReturns;
        totalNet += pl.netSales;
        totalCogs += pl.netCogs;
        totalGrossProf += pl.grossProfit;
        totalExp += pl.operatingExpenses;
        totalNetProf += pl.netProfit;

        monthlyBreakdown.add(MonthlyProfitRow(
          monthNumber: m,
          monthName: monthNames[m - 1],
          grossSales: pl.grossSales,
          salesReturns: pl.salesReturns,
          netSales: pl.netSales,
          netCogs: pl.netCogs,
          grossProfit: pl.grossProfit,
          expenses: pl.operatingExpenses,
          netProfit: pl.netProfit,
        ));
      }

      return YearlyReportData(
        year: year,
        totalGrossSales: totalGross,
        totalSalesReturns: totalReturns,
        netSales: totalNet,
        totalNetCogs: totalCogs,
        totalGrossProfit: totalGrossProf,
        totalExpenses: totalExp,
        totalNetProfit: totalNetProf,
        monthlyBreakdown: monthlyBreakdown,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج التقرير السنوي', e);
    }
  }
}
