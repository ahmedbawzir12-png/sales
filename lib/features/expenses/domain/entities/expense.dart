/// كيان المصروف التشغيلي (Expense)
class Expense {
  final int id;
  final String categoryName;
  final int amount;
  final DateTime expenseDate;
  final String description;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.expenseDate,
    required this.description,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    int? id,
    String? categoryName,
    int? amount,
    DateTime? expenseDate,
    String? description,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Expense(id: $id, cat: $categoryName, amount: $amount, desc: $description)';
}
