import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/category.dart';

/// نموذج بيانات التصنيف في طبقة البيانات
class CategoryModel extends DataModel<Category> {
  final int id;
  final String name;
  final String? description;
  final int isActive;
  final String createdAt;
  final String updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      isActive: map['is_active'] as int? ?? 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory CategoryModel.fromEntity(Category entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      isActive: entity.isActive ? 1 : 0,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
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
  Category toEntity() {
    return Category(
      id: id,
      name: name,
      description: description,
      isActive: isActive == 1,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
    );
  }
}
