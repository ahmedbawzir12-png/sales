import 'package:sales/core/domain/entities/entity.dart';

/// سطر وبند في فاتورة المبيعات في طبقة النطاق
class SalesInvoiceItem extends Entity {
  final int id;
  final int salesInvoiceId;
  final int productId;
  final double quantity;
  final int unitPrice; // سعر البيع المتفق عليه للوحدة بالريال
  final double unitCostAtSale; // متوسط تكلفة الوحدة للمنتج المسجل تاريخياً وقت البيع
  final int discount; // خصم السطر إن وجد
  final int total; // إجمالي السطر = (الكمية × سعر البيع) - الخصم
  final double costTotal; // إجمالي التكلفة التاريخية للسطر = الكمية × متوسط التكلفة وقت البيع

  // حقول مساعدة للعرض
  final String? productName;
  final String? unitSymbol;

  const SalesInvoiceItem({
    required this.id,
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

  /// الربح الإجمالي التقديري لهذا السطر = إجمالي البيع - إجمالي التكلفة
  double get grossProfit => total - costTotal;

  SalesInvoiceItem copyWith({
    int? id,
    int? salesInvoiceId,
    int? productId,
    double? quantity,
    int? unitPrice,
    double? unitCostAtSale,
    int? discount,
    int? total,
    double? costTotal,
    String? productName,
    String? unitSymbol,
  }) {
    return SalesInvoiceItem(
      id: id ?? this.id,
      salesInvoiceId: salesInvoiceId ?? this.salesInvoiceId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostAtSale: unitCostAtSale ?? this.unitCostAtSale,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      costTotal: costTotal ?? this.costTotal,
      productName: productName ?? this.productName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoiceItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          salesInvoiceId == other.salesInvoiceId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          (unitCostAtSale - other.unitCostAtSale).abs() < 0.001;

  @override
  int get hashCode => Object.hash(
        id,
        salesInvoiceId,
        productId,
        quantity,
        unitPrice,
        unitCostAtSale,
      );

  @override
  String toString() =>
      'SalesInvoiceItem(id: $id, product: $productId, qty: $quantity, price: $unitPrice, costAtSale: $unitCostAtSale, total: $total)';
}
