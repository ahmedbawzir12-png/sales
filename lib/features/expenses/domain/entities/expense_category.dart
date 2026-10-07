/// كيان تصنيف المصروفات
class ExpenseCategory {
  final int id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ExpenseCategory(id: $id, name: $name)';
}
