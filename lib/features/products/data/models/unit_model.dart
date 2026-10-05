import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/unit_of_measurement.dart';

/// نموذج بيانات وحدة القياس في طبقة البيانات
class UnitModel extends DataModel<UnitOfMeasurement> {
  final int id;
  final String name;
  final String symbol;
  final String createdAt;

  const UnitModel({
    required this.id,
    required this.name,
    required this.symbol,
    required this.createdAt,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map) {
    return UnitModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      symbol: map['symbol'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory UnitModel.fromEntity(UnitOfMeasurement entity) {
    return UnitModel(
      id: entity.id,
      name: entity.name,
      symbol: entity.symbol,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'symbol': symbol,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  @override
  UnitOfMeasurement toEntity() {
    return UnitOfMeasurement(
      id: id,
      name: name,
      symbol: symbol,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
    );
  }
}
