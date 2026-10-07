import '../../domain/entities/expense_category.dart';

/// نموذج تصنيف المصروفات في طبقة البيانات
class ExpenseCategoryModel {
  final int id;
  final String name;
  final int isActive;
  final String createdAt;

  const ExpenseCategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  factory ExpenseCategoryModel.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String,
      isActive: map['is_active'] as int? ?? 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'is_active': isActive,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  ExpenseCategory toEntity() {
    return ExpenseCategory(
      id: id,
      name: name,
      isActive: isActive == 1,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
