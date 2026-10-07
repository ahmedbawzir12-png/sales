import '../entities/dashboard_summary.dart';
import '../entities/low_stock_product_item.dart';

/// واجهة مستودع لوحة التحكم (Read-Only)
abstract class DashboardRepository {
  /// استرجاع ملخص مؤشرات لوحة التحكم الرئيسية
  Future<DashboardSummary> getDashboardSummary();

  /// استرجاع قائمة الأصناف منخفضة المخزون
  Future<List<LowStockProductItem>> getLowStockProducts();
}
