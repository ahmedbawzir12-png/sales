/// سطر تقرير حركة المخزون
class StockMovementReportRow {
  final int id;
  final int productId;
  final String productName;
  final String categoryName;
  final String unitSymbol;
  final String movementType; // نوع الحركة بالعربي
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String reason;
  final String? reference;
  final DateTime createdAt;

  const StockMovementReportRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.unitSymbol,
    required this.movementType,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.reason,
    this.reference,
    required this.createdAt,
  });

  bool get isAddition => stockAfter > stockBefore;
}
