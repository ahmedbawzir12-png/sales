import 'package:sales/core/domain/entities/entity.dart';

/// كيان سطر / بند فاتورة الشراء
class PurchaseInvoiceItem extends Entity {
  final int id;
  final int purchaseInvoiceId;
  final int productId;
  final double quantity;
  final int unitCost;
  final int total;

  // حقول بيانات مساعدة للعرض
  final String? productName;
  final String? unitSymbol;

  const PurchaseInvoiceItem({
    required this.id,
    required this.purchaseInvoiceId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.total,
    this.productName,
    this.unitSymbol,
  });

  PurchaseInvoiceItem copyWith({
    int? id,
    int? purchaseInvoiceId,
    int? productId,
    double? quantity,
    int? unitCost,
    int? total,
    String? productName,
    String? unitSymbol,
  }) {
    return PurchaseInvoiceItem(
      id: id ?? this.id,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      total: total ?? this.total,
      productName: productName ?? this.productName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseInvoiceItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          purchaseInvoiceId == other.purchaseInvoiceId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitCost == other.unitCost &&
          total == other.total;

  @override
  int get hashCode => Object.hash(
        id,
        purchaseInvoiceId,
        productId,
        quantity,
        unitCost,
        total,
      );

  @override
  String toString() =>
      'PurchaseInvoiceItem(id: $id, product: $productId, qty: $quantity, cost: $unitCost, total: $total)';
}
