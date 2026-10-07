import '../entities/date_range.dart';
import '../entities/debts_report_data.dart';
import '../entities/expenses_report_data.dart';
import '../entities/inventory_report_data.dart';
import '../entities/profit_loss_report_data.dart';
import '../entities/purchases_report_data.dart';
import '../entities/sales_report_data.dart';
import '../entities/stock_movement_report_row.dart';
import '../entities/yearly_report_data.dart';

/// واجهة مستودع التقارير الشاملة للنظام (Read-Only)
abstract class ReportsRepository {
  /// استرجاع تقرير المبيعات للفترة المحددة
  Future<SalesReportData> getSalesReport(DateRange range);

  /// استرجاع تقرير المشتريات للفترة المحددة
  Future<PurchasesReportData> getPurchasesReport(DateRange range);

  /// استرجاع تقرير المخزون وحالة الأصناف
  Future<InventoryReportData> getInventoryReport();

  /// استرجاع سجل حركة المخزون مع الفلترة الاختيارية
  Future<List<StockMovementReportRow>> getStockMovementsReport({
    DateRange? range,
    int? productId,
  });

  /// استرجاع تقرير الديون الشامل (أرصدة العملاء والموردين)
  Future<DebtsReportData> getDebtsReport();

  /// استرجاع تقرير المصروفات وتوزيعها للفترة المحددة
  Future<ExpensesReportData> getExpensesReport(DateRange range);

  /// استرجاع تقرير الأرباح والخسائر للفترة المحددة
  Future<ProfitLossReportData> getProfitLossReport(DateRange range);

  /// استرجاع التقرير السنوي مع التفصيل الشهري
  Future<YearlyReportData> getYearlyReport(int year);
}
