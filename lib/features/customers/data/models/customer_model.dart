import '../../domain/entities/customer.dart';

/// نموذج بيانات العميل للتحويل والتخزين في SQLite
class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? notes;
  final int currentBalance;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    this.notes,
    this.currentBalance = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromEntity(Customer entity) {
    return CustomerModel(
      id: entity.id == 0 ? null : entity.id,
      name: entity.name,
      phone: entity.phone,
      whatsapp: entity.whatsapp,
      address: entity.address,
      notes: entity.notes,
      currentBalance: entity.currentBalance,
      isActive: entity.isActive,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }

  Customer toEntity() {
    return Customer(
      id: id ?? 0,
      name: name,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
      notes: notes,
      currentBalance: currentBalance,
      isActive: isActive,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      currentBalance: (map['current_balance'] as num?)?.toInt() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'address': address,
      'notes': notes,
      'current_balance': currentBalance,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
