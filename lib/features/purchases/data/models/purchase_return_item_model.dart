import '../../domain/entities/purchase_return_item.dart';

class PurchaseReturnItemModel {
  final int id;
  final int purchaseReturnId;
  final int productId;
  final String? productName;
  final double quantity;
  final int unitCost;
  final int total;

  const PurchaseReturnItemModel({
    required this.id,
    required this.purchaseReturnId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitCost,
    required this.total,
  });

  factory PurchaseReturnItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnItemModel(
      id: (map['id'] as num).toInt(),
      purchaseReturnId: (map['purchase_return_id'] as num).toInt(),
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toInt(),
      total: (map['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'purchase_return_id': purchaseReturnId,
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total': total,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  PurchaseReturnItem toEntity() {
    return PurchaseReturnItem(
      id: id,
      purchaseReturnId: purchaseReturnId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitCost: unitCost,
      total: total,
    );
  }

  factory PurchaseReturnItemModel.fromEntity(PurchaseReturnItem entity) {
    return PurchaseReturnItemModel(
      id: entity.id,
      purchaseReturnId: entity.purchaseReturnId,
      productId: entity.productId,
      productName: entity.productName,
      quantity: entity.quantity,
      unitCost: entity.unitCost,
      total: entity.total,
    );
  }
}
