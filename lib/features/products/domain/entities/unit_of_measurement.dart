import 'package:sales/core/domain/entities/entity.dart';

/// كيان وحدة القياس في طبقة النطاق
class UnitOfMeasurement extends Entity {
  final int id;
  final String name;
  final String symbol;
  final DateTime createdAt;

  const UnitOfMeasurement({
    required this.id,
    required this.name,
    required this.symbol,
    required this.createdAt,
  });

  UnitOfMeasurement copyWith({
    int? id,
    String? name,
    String? symbol,
    DateTime? createdAt,
  }) {
    return UnitOfMeasurement(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitOfMeasurement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          symbol == symbol;

  @override
  int get hashCode => Object.hash(id, name, symbol);

  @override
  String toString() => 'UnitOfMeasurement(id: $id, name: $name, symbol: $symbol)';
}
