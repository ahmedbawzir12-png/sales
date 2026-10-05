import 'package:sales/core/domain/entities/entity.dart';

/// كيان تصنيف المنتجات في طبقة النطاق
class Category extends Entity {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, name, description, isActive);

  @override
  String toString() => 'Category(id: $id, name: $name, isActive: $isActive)';
}
