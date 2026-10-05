import '../../domain/entities/sales_invoice_item.dart';

/// نموذج بند وتفاصيل فاتورة المبيعات للتحويل والتخزين في SQLite
class SalesInvoiceItemModel {
  final int? id;
  final int salesInvoiceId;
  final int productId;
  final double quantity;
  final int unitPrice;
  final double unitCostAtSale;
  final int discount;
  final int total;
  final double costTotal;

  // حقول للعرض
  final String? productName;
  final String? unitSymbol;

  const SalesInvoiceItemModel({
    this.id,
    required this.salesInvoiceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCostAtSale,
    this.discount = 0,
    required this.total,
    required this.costTotal,
    this.productName,
    this.unitSymbol,
  });

  factory SalesInvoiceItemModel.fromEntity(SalesInvoiceItem entity) {
    return SalesInvoiceItemModel(
      id: entity.id == 0 ? null : entity.id,
      salesInvoiceId: entity.salesInvoiceId,
      productId: entity.productId,
      quantity: entity.quantity,
      unitPrice: entity.unitPrice,
      unitCostAtSale: entity.unitCostAtSale,
      discount: entity.discount,
      total: entity.total,
      costTotal: entity.costTotal,
      productName: entity.productName,
      unitSymbol: entity.unitSymbol,
    );
  }

  SalesInvoiceItem toEntity() {
    return SalesInvoiceItem(
      id: id ?? 0,
      salesInvoiceId: salesInvoiceId,
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      unitCostAtSale: unitCostAtSale,
      discount: discount,
      total: total,
      costTotal: costTotal,
      productName: productName,
      unitSymbol: unitSymbol,
    );
  }

  factory SalesInvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return SalesInvoiceItemModel(
      id: map['id'] as int?,
      salesInvoiceId: (map['sales_invoice_id'] as num).toInt(),
      productId: (map['product_id'] as num).toInt(),
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toInt(),
      unitCostAtSale: (map['unit_cost_at_sale'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num).toInt(),
      costTotal: (map['cost_total'] as num).toDouble(),
      productName: map['product_name'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sales_invoice_id': salesInvoiceId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost_at_sale': unitCostAtSale,
      'discount': discount,
      'total': total,
      'cost_total': costTotal,
    };
  }
}
