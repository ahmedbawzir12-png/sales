/// سطر تقرير صنف في المخزون
class InventoryReportRow {
  final int id;
  final String name;
  final String categoryName;
  final String unitSymbol;
  final double currentStock;
  final double minimumStock;
  final double averageCost;
  final double totalCostValue;
  final int salePrice;
  final String status; // 'متوفر', 'منخفض', 'نفد'

  const InventoryReportRow({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.unitSymbol,
    required this.currentStock,
    required this.minimumStock,
    required this.averageCost,
    required this.totalCostValue,
    required this.salePrice,
    required this.status,
  });

  bool get isLow => status == 'منخفض';
  bool get isOut => status == 'نفد';
}

/// بيانات تقرير المخزون العام
class InventoryReportData {
  final int totalProductsCount;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockQuantity;
  final double totalInventoryCostValue;
  final int totalInventorySaleValue;
  final List<InventoryReportRow> items;

  const InventoryReportData({
    required this.totalProductsCount,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalStockQuantity,
    required this.totalInventoryCostValue,
    required this.totalInventorySaleValue,
    required this.items,
  });

  factory InventoryReportData.empty() {
    return const InventoryReportData(
      totalProductsCount: 0,
      inStockCount: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      totalStockQuantity: 0.0,
      totalInventoryCostValue: 0.0,
      totalInventorySaleValue: 0,
      items: [],
    );
  }
}
