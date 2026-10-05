import 'package:sales/core/domain/entities/entity.dart';

/// كيان بند من بنود مرتجع المبيعات
class SalesReturnItem extends Entity {
  final int id;
  final int salesReturnId;
  final int productId;
  final String? productName;
  final double quantity;
  final int unitPrice;
  final double unitCostAtSale;
  final int total;

  const SalesReturnItem({
    required this.id,
    required this.salesReturnId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCostAtSale,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesReturnItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  SalesReturnItem copyWith({
    int? id,
    int? salesReturnId,
    int? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? unitCostAtSale,
    int? total,
  }) {
    return SalesReturnItem(
      id: id ?? this.id,
      salesReturnId: salesReturnId ?? this.salesReturnId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostAtSale: unitCostAtSale ?? this.unitCostAtSale,
      total: total ?? this.total,
    );
  }
}
