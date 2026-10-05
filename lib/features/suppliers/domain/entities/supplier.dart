import 'package:sales/core/domain/entities/entity.dart';

/// كيان المورد في طبقة النطاق
class Supplier extends Entity {
  final int id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? notes;
  final int currentBalance; // رصيد دين المورد المستحق (ما للمورد على المحل بالريال اليمني)
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
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

  /// التحقق من صلاحية بيانات المورد
  bool get isValid => name.trim().isNotEmpty;

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? address,
    String? notes,
    int? currentBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          (id != 0 && other.id != 0 ? id == other.id : id == other.id && name == other.name);

  @override
  int get hashCode => id != 0 ? id.hashCode : Object.hash(id, name);

  @override
  String toString() =>
      'Supplier(id: $id, name: $name, phone: $phone, balance: $currentBalance, active: $isActive)';
}
