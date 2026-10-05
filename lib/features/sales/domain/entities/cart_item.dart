import '../../../products/domain/entities/product.dart';

/// عنصر سلة البيع في واجهة نقطة البيع المؤقتة
class CartItem {
  final Product product;
  double quantity;
  int unitPrice; // السعر القابل للتعديل
  int discount;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    int? unitPrice,
    this.discount = 0,
  }) : unitPrice = unitPrice ?? product.salePrice;

  /// إجمالي السطر المحسوب
  int get calculatedTotal {
    final raw = (quantity * unitPrice).round();
    final afterDiscount = raw - discount;
    return afterDiscount > 0 ? afterDiscount : 0;
  }

  /// إجمالي التكلفة التقديرية بناءً على متوسط تكلفة الصنف الحالي
  double get estimatedCostTotal => quantity * product.averageCost;

  /// هل هناك كمية كافية في المستودع؟
  bool get hasEnoughStock => product.currentStock >= quantity;

  /// نسخة جديدة من العنصر
  CartItem copyWith({
    Product? product,
    double? quantity,
    int? unitPrice,
    int? discount,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
    );
  }
}
