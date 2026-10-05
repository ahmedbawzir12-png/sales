import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/purchase_invoice_item.dart';

/// نموذج بيانات سطر فاتورة الشراء في SQLite
class PurchaseInvoiceItemModel extends DataModel<PurchaseInvoiceItem> {
  final int id;
  final int purchaseInvoiceId;
  final int productId;
  final double quantity;
  final int unitCost;
  final int total;

  // حقول من الجداول المنضمة (JOINs)
  final String? productName;
  final String? unitSymbol;

  const PurchaseInvoiceItemModel({
    required this.id,
    required this.purchaseInvoiceId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.total,
    this.productName,
    this.unitSymbol,
  });

  factory PurchaseInvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItemModel(
      id: map['id'] as int? ?? 0,
      purchaseInvoiceId: map['purchase_invoice_id'] as int? ?? 0,
      productId: map['product_id'] as int? ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: map['unit_cost'] as int? ?? 0,
      total: map['total'] as int? ?? 0,
      productName: map['product_name'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
    );
  }

  factory PurchaseInvoiceItemModel.fromEntity(PurchaseInvoiceItem entity) {
    return PurchaseInvoiceItemModel(
      id: entity.id,
      purchaseInvoiceId: entity.purchaseInvoiceId,
      productId: entity.productId,
      quantity: entity.quantity,
      unitCost: entity.unitCost,
      total: entity.total,
      productName: entity.productName,
      unitSymbol: entity.unitSymbol,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'purchase_invoice_id': purchaseInvoiceId,
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

  @override
  PurchaseInvoiceItem toEntity() {
    return PurchaseInvoiceItem(
      id: id,
      purchaseInvoiceId: purchaseInvoiceId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      total: total,
      productName: productName,
      unitSymbol: unitSymbol,
    );
  }
}
