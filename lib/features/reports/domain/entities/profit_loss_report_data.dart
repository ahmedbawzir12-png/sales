import 'date_range.dart';

/// بيانات تقرير الأرباح والخسائر (Profit & Loss Statement)
/// يتم الحساب حصرياً من البيانات التاريخية الفعلية وبأخذ أثر المرتجعات والمصروفات التشغيلية بعين الاعتبار
class ProfitLossReportData {
  final DateRange dateRange;
  final int grossSales; // إجمالي المبيعات قبل المرتجعات
  final int salesReturns; // مرتجعات المبيعات
  final int netSales; // صافي المبيعات = الإجمالي - المرتجعات
  final double grossCogs; // تكلفة البضاعة المباعة التاريخية
  final double returnedCogs; // تكلفة البضاعة المسترجعة تاريخياً
  final double netCogs; // صافي تكلفة البضاعة المباعة = grossCogs - returnedCogs
  final double grossProfit; // الربح الإجمالي = netSales - netCogs
  final int operatingExpenses; // المصروفات التشغيلية المستبعد منها سحوبات المالك ومدفوعات الموردين
  final double netProfit; // صافي الربح = grossProfit - operatingExpenses

  const ProfitLossReportData({
    required this.dateRange,
    required this.grossSales,
    required this.salesReturns,
    required this.netSales,
    required this.grossCogs,
    required this.returnedCogs,
    required this.netCogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
  });

  /// هامش الربح الصافي كنسبة مئوية من صافي المبيعات
  double get profitMargin =>
      netSales > 0 ? (netProfit / netSales) * 100 : 0.0;

  /// هامش الربح الإجمالي كنسبة مئوية من صافي المبيعات
  double get grossMargin =>
      netSales > 0 ? (grossProfit / netSales) * 100 : 0.0;

  factory ProfitLossReportData.empty(DateRange range) {
    return ProfitLossReportData(
      dateRange: range,
      grossSales: 0,
      salesReturns: 0,
      netSales: 0,
      grossCogs: 0.0,
      returnedCogs: 0.0,
      netCogs: 0.0,
      grossProfit: 0.0,
      operatingExpenses: 0,
      netProfit: 0.0,
    );
  }
}
