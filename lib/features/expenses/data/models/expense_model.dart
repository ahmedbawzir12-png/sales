import '../../domain/entities/expense.dart';

/// نموذج بيانات المصروف التشغيلي في طبقة البيانات
class ExpenseModel {
  final int id;
  final String categoryName;
  final int amount;
  final String expenseDate;
  final String description;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const ExpenseModel({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.expenseDate,
    required this.description,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int? ?? 0,
      categoryName: map['category_name'] as String,
      amount: map['amount'] as int,
      expenseDate: map['expense_date'] as String,
      description: map['description'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'category_name': categoryName,
      'amount': amount,
      'expense_date': expenseDate,
      'description': description,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  Expense toEntity() {
    return Expense(
      id: id,
      categoryName: categoryName,
      amount: amount,
      expenseDate: DateTime.parse(expenseDate),
      description: description,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory ExpenseModel.fromEntity(Expense entity) {
    return ExpenseModel(
      id: entity.id,
      categoryName: entity.categoryName,
      amount: entity.amount,
      expenseDate: entity.expenseDate.toIso8601String(),
      description: entity.description,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}
