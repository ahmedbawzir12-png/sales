import 'package:sales/core/domain/entities/entity.dart';

/// كيان المنتج في طبقة النطاق
class Product extends Entity {
  final int id;
  final String name;
  final int categoryId;
  final int unitId;
  final int purchasePrice;
  final int salePrice;
  final double averageCost;
  final double currentStock;
  final double minimumStock;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // حقول بيانات مساعدة للعرض (تُملأ عند الربط مع الجداول الأخرى)
  final String? categoryName;
  final String? unitSymbol;

  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.purchasePrice,
    required this.salePrice,
    double? averageCost,
    this.currentStock = 0.0,
    this.minimumStock = 0.0,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.unitSymbol,
  }) : averageCost = averageCost ?? purchasePrice * 1.0;

  /// هل المخزون وصل أو نزل عن حد إعادة الطلب الأدنى؟
  bool get isLowStock => currentStock <= minimumStock;

  Product copyWith({
    int? id,
    String? name,
    int? categoryId,
    int? unitId,
    int? purchasePrice,
    int? salePrice,
    double? averageCost,
    double? currentStock,
    double? minimumStock,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? unitSymbol,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      averageCost: averageCost ?? this.averageCost,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          (id != 0 && other.id != 0 ? id == other.id : id == other.id && name == other.name);

  @override
  int get hashCode => id != 0 ? id.hashCode : Object.hash(id, name);

  @override
  String toString() =>
      'Product(id: $id, name: $name, stock: $currentStock, price: $salePrice, active: $isActive)';
}
