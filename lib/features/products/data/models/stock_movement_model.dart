import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/stock_movement.dart';

/// نموذج بيانات حركة المخزون في طبقة البيانات
class StockMovementModel extends DataModel<StockMovement> {
  final int id;
  final int productId;
  final String movementType;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String reason;
  final String? notes;
  final String? reference;
  final String createdAt;

  const StockMovementModel({
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

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as int? ?? 0,
      productId: map['product_id'] as int? ?? 0,
      movementType: map['movement_type'] as String? ?? 'initialStock',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      stockBefore: (map['stock_before'] as num?)?.toDouble() ?? 0.0,
      stockAfter: (map['stock_after'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String? ?? '',
      notes: map['notes'] as String?,
      reference: map['reference'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory StockMovementModel.fromEntity(StockMovement entity) {
    return StockMovementModel(
      id: entity.id,
      productId: entity.productId,
      movementType: entity.movementType.name,
      quantity: entity.quantity,
      stockBefore: entity.stockBefore,
      stockAfter: entity.stockAfter,
      reason: entity.reason,
      notes: entity.notes,
      reference: entity.reference,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'product_id': productId,
      'movement_type': movementType,
      'quantity': quantity,
      'stock_before': stockBefore,
      'stock_after': stockAfter,
      'reason': reason,
      'notes': notes,
      'reference': reference,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  @override
  StockMovement toEntity() {
    StockMovementType type;
    try {
      type = StockMovementType.values.byName(movementType);
    } catch (_) {
      type = StockMovementType.adjustmentIncrease;
    }

    return StockMovement(
      id: id,
      productId: productId,
      movementType: type,
      quantity: quantity,
      stockBefore: stockBefore,
      stockAfter: stockAfter,
      reason: reason,
      notes: notes,
      reference: reference,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
    );
  }
}
