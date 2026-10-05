import 'package:sales/core/domain/entities/entity.dart';

/// أنواع حركات المخزون في النظام
enum StockMovementType {
  initialStock,
  adjustmentIncrease,
  adjustmentDecrease,
  purchase,
  sale,
  saleReturn,
  purchaseReturn;

  /// الوصف العربي لنوع الحركة
  String get arabicLabel {
    switch (this) {
      case StockMovementType.initialStock:
        return 'مخزون افتتاحي';
      case StockMovementType.adjustmentIncrease:
        return 'تسوية جردية (زيادة)';
      case StockMovementType.adjustmentDecrease:
        return 'تسوية جردية (عجز)';
      case StockMovementType.purchase:
        return 'فاتورة مشتريات';
      case StockMovementType.sale:
        return 'فاتورة مبيعات';
      case StockMovementType.saleReturn:
        return 'مرتجع مبيعات';
      case StockMovementType.purchaseReturn:
        return 'مرتجع مشتريات';
    }
  }

  /// هل الحركة تؤدي لزيادة رصيد المخزون؟
  bool get isAddition {
    switch (this) {
      case StockMovementType.initialStock:
      case StockMovementType.adjustmentIncrease:
      case StockMovementType.purchase:
      case StockMovementType.saleReturn:
        return true;
      case StockMovementType.adjustmentDecrease:
      case StockMovementType.sale:
      case StockMovementType.purchaseReturn:
        return false;
    }
  }
}

/// كيان حركة المخزون في طبقة النطاق
class StockMovement extends Entity {
  final int id;
  final int productId;
  final StockMovementType movementType;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String reason;
  final String? notes;
  final String? reference;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.reason,
    this.notes,
    this.reference,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          movementType == other.movementType &&
          quantity == other.quantity &&
          stockBefore == other.stockBefore &&
          stockAfter == other.stockAfter;

  @override
  int get hashCode => Object.hash(
        id,
        productId,
        movementType,
        quantity,
        stockBefore,
        stockAfter,
      );

  @override
  String toString() =>
      'StockMovement(id: $id, productId: $productId, type: ${movementType.arabicLabel}, qty: $quantity)';
}
