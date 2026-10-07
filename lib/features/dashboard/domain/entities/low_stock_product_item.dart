/// كيان صنف منخفض المخزون في لوحة التحكم
class LowStockProductItem {
  final int id;
  final String name;
  final String categoryName;
  final String unitSymbol;
  final double currentStock;
  final double minimumStock;
  final double difference; // minimumStock - currentStock

  const LowStockProductItem({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.unitSymbol,
    required this.currentStock,
    required this.minimumStock,
    required this.difference,
  });
}
