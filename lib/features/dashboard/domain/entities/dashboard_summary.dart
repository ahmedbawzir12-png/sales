import 'low_stock_product_item.dart';

/// ملخص المؤشرات الرئيسية في لوحة التحكم لصاحب المعرض (Dashboard Summary)
class DashboardSummary {
  // مؤشرات اليوم
  final int todayGrossSales;
  final int todaySalesReturns;
  final int todayNetSales;
  final double todayGrossProfit;
  final int todayExpenses;
  final double todayNetProfit;

  // مؤشرات الشهر الحالي
  final int monthGrossSales;
  final int monthSalesReturns;
  final int monthNetSales;
  final double monthGrossProfit;
  final int monthExpenses;
  final double monthNetProfit;

  // مؤشرات الديون والمالية
  final int customerDebtTotal;
  final int supplierDebtTotal;
  final int cashBalance;

  // مؤشرات المستودع والمخزون
  final double inventoryCostValue;
  final int inventoryTotalItems;
  final int lowStockCount;
  final List<LowStockProductItem> lowStockProducts;

  const DashboardSummary({
    required this.todayGrossSales,
    required this.todaySalesReturns,
    required this.todayNetSales,
    required this.todayGrossProfit,
    required this.todayExpenses,
    required this.todayNetProfit,
    required this.monthGrossSales,
    required this.monthSalesReturns,
    required this.monthNetSales,
    required this.monthGrossProfit,
    required this.monthExpenses,
    required this.monthNetProfit,
    required this.customerDebtTotal,
    required this.supplierDebtTotal,
    required this.cashBalance,
    required this.inventoryCostValue,
    required this.inventoryTotalItems,
    required this.lowStockCount,
    required this.lowStockProducts,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      todayGrossSales: 0,
      todaySalesReturns: 0,
      todayNetSales: 0,
      todayGrossProfit: 0.0,
      todayExpenses: 0,
      todayNetProfit: 0.0,
      monthGrossSales: 0,
      monthSalesReturns: 0,
      monthNetSales: 0,
      monthGrossProfit: 0.0,
      monthExpenses: 0,
      monthNetProfit: 0.0,
      customerDebtTotal: 0,
      supplierDebtTotal: 0,
      cashBalance: 0,
      inventoryCostValue: 0.0,
      inventoryTotalItems: 0,
      lowStockCount: 0,
      lowStockProducts: [],
    );
  }
}
