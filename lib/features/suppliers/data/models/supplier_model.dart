import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/supplier.dart';

/// نموذج بيانات المورد في طبقة البيانات لـ SQLite
class SupplierModel extends DataModel<Supplier> {
  final int id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? notes;
  final int currentBalance;
  final int isActive;
  final String createdAt;
  final String updatedAt;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.notes,
    this.currentBalance = 0,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      currentBalance: map['current_balance'] as int? ?? 0,
      isActive: map['is_active'] as int? ?? 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory SupplierModel.fromEntity(Supplier entity) {
    return SupplierModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      whatsapp: entity.whatsapp,
      address: entity.address,
      notes: entity.notes,
      currentBalance: entity.currentBalance,
      isActive: entity.isActive ? 1 : 0,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'address': address,
      'notes': notes,
      'current_balance': currentBalance,
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
  Supplier toEntity() {
    return Supplier(
      id: id,
      name: name,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
      notes: notes,
      currentBalance: currentBalance,
      isActive: isActive == 1,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
    );
  }
}
