import 'package:sales/core/domain/entities/entity.dart';

/// كيان بند من بنود مرتجع المشتريات
class PurchaseReturnItem extends Entity {
  final int id;
  final int purchaseReturnId;
  final int productId;
  final String? productName;
  final double quantity;
  final int unitCost;
  final int total;

  const PurchaseReturnItem({
    required this.id,
    required this.purchaseReturnId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitCost,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseReturnItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  PurchaseReturnItem copyWith({
    int? id,
    int? purchaseReturnId,
    int? productId,
    String? productName,
    double? quantity,
    int? unitCost,
    int? total,
  }) {
    return PurchaseReturnItem(
      id: id ?? this.id,
      purchaseReturnId: purchaseReturnId ?? this.purchaseReturnId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      total: total ?? this.total,
    );
  }
}
