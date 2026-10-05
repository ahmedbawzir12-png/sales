import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/product.dart';

/// نموذج بيانات المنتج في طبقة البيانات
class ProductModel extends DataModel<Product> {
  final int id;
  final String name;
  final int categoryId;
  final int unitId;
  final int purchasePrice;
  final int salePrice;
  final double currentStock;
  final double minimumStock;
  final String? description;
  final int isActive;
  final String createdAt;
  final String updatedAt;

  // حقول من الجداول المترابطة عند الاستعلام
  final String? categoryName;
  final String? unitSymbol;

  const ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.purchasePrice,
    required this.salePrice,
    this.currentStock = 0.0,
    this.minimumStock = 0.0,
    this.description,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.unitSymbol,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      categoryId: map['category_id'] as int? ?? 0,
      unitId: map['unit_id'] as int? ?? 0,
      purchasePrice: map['purchase_price'] as int? ?? 0,
      salePrice: map['sale_price'] as int? ?? 0,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimum_stock'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      isActive: map['is_active'] as int? ?? 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      categoryName: map['category_name'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
    );
  }

  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      id: entity.id,
      name: entity.name,
      categoryId: entity.categoryId,
      unitId: entity.unitId,
      purchasePrice: entity.purchasePrice,
      salePrice: entity.salePrice,
      currentStock: entity.currentStock,
      minimumStock: entity.minimumStock,
      description: entity.description,
      isActive: entity.isActive ? 1 : 0,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
      categoryName: entity.categoryName,
      unitSymbol: entity.unitSymbol,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'category_id': categoryId,
      'unit_id': unitId,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  @override
  Product toEntity() {
    return Product(
      id: id,
      name: name,
      categoryId: categoryId,
      unitId: unitId,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      currentStock: currentStock,
      minimumStock: minimumStock,
      description: description,
      isActive: isActive == 1,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
      categoryName: categoryName,
      unitSymbol: unitSymbol,
    );
  }
}
