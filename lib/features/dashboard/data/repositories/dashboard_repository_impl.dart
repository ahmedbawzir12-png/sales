import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../../reports/data/repositories/reports_repository_impl.dart';
import '../../../reports/domain/entities/date_range.dart';
import '../../../reports/domain/repositories/reports_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/low_stock_product_item.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// تطبيق مستودع لوحة التحكم لصاحب المتجر (Read-Only)
class DashboardRepositoryImpl implements DashboardRepository {
  final DatabaseService _dbService;
  final ReportsRepository _reportsRepo;

  DashboardRepositoryImpl({
    DatabaseService? dbService,
    ReportsRepository? reportsRepo,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _reportsRepo = reportsRepo ??
            ReportsRepositoryImpl(dbService: dbService ?? DatabaseService.instance);

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    try {
      final db = await _dbService.database;

      // 1. حساب مؤشرات اليوم والأرباح الحقيقية
      final todayRange = DateRange.today();
      final todayPL = await _reportsRepo.getProfitLossReport(todayRange);

      // 2. حساب مؤشرات الشهر الحالي والأرباح الحقيقية
      final monthRange = DateRange.currentMonth();
      final monthPL = await _reportsRepo.getProfitLossReport(monthRange);

      // 3. حساب رصيد الصندوق النقدي الفعلي
      final cashRes = await db.rawQuery('''
        SELECT COALESCE(
          SUM(CASE 
            WHEN direction = 'cashIn' THEN amount 
            WHEN direction = 'cashOut' THEN -amount 
            ELSE 0 
          END), 
          0
        ) AS balance
        FROM ${DatabaseConstants.tableCashTransactions};
      ''');
      final cashBalance = (cashRes.first['balance'] as num?)?.toInt() ?? 0;

      // 4. حساب ديون العملاء الإجمالية من الأستاذ العام
      final custDebtRes = await db.rawQuery('''
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
      final customerDebt = (custDebtRes.first['total_debt'] as num?)?.toInt() ?? 0;

      // 5. حساب ديون الموردين الإجمالية من الأستاذ العام
      final suppDebtRes = await db.rawQuery('''
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
      final supplierDebt = (suppDebtRes.first['total_debt'] as num?)?.toInt() ?? 0;

      // 6. حساب قيمة المخزون الحالية بالتكلفة وعدد الأصناف والمنخفضات
      final invRes = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(current_stock * average_cost), 0.0) AS inventory_cost,
          COUNT(*) AS total_items,
          COALESCE(SUM(CASE WHEN current_stock <= minimum_stock THEN 1 ELSE 0 END), 0) AS low_count
        FROM ${DatabaseConstants.tableProducts}
        WHERE is_active = 1;
      ''');
      final invRow = invRes.first;
      final inventoryCost = (invRow['inventory_cost'] as num?)?.toDouble() ?? 0.0;
      final totalItems = (invRow['total_items'] as num?)?.toInt() ?? 0;
      final lowCount = (invRow['low_count'] as num?)?.toInt() ?? 0;

      // 7. جلب قائمة الأصناف منخفضة المخزون
      final lowStockItems = await getLowStockProducts();

      return DashboardSummary(
        todayGrossSales: todayPL.grossSales,
        todaySalesReturns: todayPL.salesReturns,
        todayNetSales: todayPL.netSales,
        todayGrossProfit: todayPL.grossProfit,
        todayExpenses: todayPL.operatingExpenses,
        todayNetProfit: todayPL.netProfit,
        monthGrossSales: monthPL.grossSales,
        monthSalesReturns: monthPL.salesReturns,
        monthNetSales: monthPL.netSales,
        monthGrossProfit: monthPL.grossProfit,
        monthExpenses: monthPL.operatingExpenses,
        monthNetProfit: monthPL.netProfit,
        customerDebtTotal: customerDebt,
        supplierDebtTotal: supplierDebt,
        cashBalance: cashBalance,
        inventoryCostValue: inventoryCost,
        inventoryTotalItems: totalItems,
        lowStockCount: lowCount,
        lowStockProducts: lowStockItems,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج ملخص لوحة التحكم', e);
    }
  }

  @override
  Future<List<LowStockProductItem>> getLowStockProducts() async {
    try {
      final db = await _dbService.database;

      final results = await db.rawQuery('''
        SELECT 
          p.id,
          p.name,
          COALESCE(c.name, 'عام') AS category_name,
          COALESCE(u.symbol, 'قطعة') AS unit_symbol,
          p.current_stock,
          p.minimum_stock,
          (p.minimum_stock - p.current_stock) AS difference
        FROM ${DatabaseConstants.tableProducts} p
        LEFT JOIN ${DatabaseConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        WHERE p.is_active = 1 AND p.current_stock <= p.minimum_stock
        ORDER BY difference DESC, p.current_stock ASC;
      ''');

      return results.map((row) {
        return LowStockProductItem(
          id: row['id'] as int,
          name: row['name'] as String,
          categoryName: row['category_name'] as String,
          unitSymbol: row['unit_symbol'] as String,
          currentStock: (row['current_stock'] as num).toDouble(),
          minimumStock: (row['minimum_stock'] as num).toDouble(),
          difference: (row['difference'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استخراج الأصناف منخفضة المخزون', e);
    }
  }
}
