import '../../domain/entities/sales_return_item.dart';

class SalesReturnItemModel {
  final int id;
  final int salesReturnId;
  final int productId;
  final String? productName;
  final double quantity;
  final int unitPrice;
  final double unitCostAtSale;
  final int total;

  const SalesReturnItemModel({
    required this.id,
    required this.salesReturnId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCostAtSale,
    required this.total,
  });

  factory SalesReturnItemModel.fromMap(Map<String, dynamic> map) {
    return SalesReturnItemModel(
      id: (map['id'] as num).toInt(),
      salesReturnId: (map['sales_return_id'] as num).toInt(),
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toInt(),
      unitCostAtSale: (map['unit_cost_at_sale'] as num).toDouble(),
      total: (map['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'sales_return_id': salesReturnId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost_at_sale': unitCostAtSale,
      'total': total,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  SalesReturnItem toEntity() {
    return SalesReturnItem(
      id: id,
      salesReturnId: salesReturnId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      unitCostAtSale: unitCostAtSale,
      total: total,
    );
  }

  factory SalesReturnItemModel.fromEntity(SalesReturnItem entity) {
    return SalesReturnItemModel(
      id: entity.id,
      salesReturnId: entity.salesReturnId,
      productId: entity.productId,
      productName: entity.productName,
      quantity: entity.quantity,
      unitPrice: entity.unitPrice,
      unitCostAtSale: entity.unitCostAtSale,
      total: entity.total,
    );
  }
}
