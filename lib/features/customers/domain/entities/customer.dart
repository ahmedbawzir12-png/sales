import 'package:sales/core/domain/entities/entity.dart';

/// كيان العميل في طبقة النطاق
class Customer extends Entity {
  final int id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? notes;
  final int currentBalance; // رصيد ديون العميل المستحقة للمحل بالريال
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
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

  /// التحقق من صلاحية البيانات الأساسية للعميل
  bool get isValid => name.trim().isNotEmpty;

  /// هل هذا الحساب يمثل زبوناً عاماً / نقدياً؟
  bool get isWalkInGeneralCustomer => id == 1 || name.contains('زبون عام');

  Customer copyWith({
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
    return Customer(
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
      other is Customer &&
          runtimeType == other.runtimeType &&
          (id != 0 && other.id != 0 ? id == other.id : id == other.id && name == other.name);

  @override
  int get hashCode => id != 0 ? id.hashCode : Object.hash(id, name);

  @override
  String toString() =>
      'Customer(id: $id, name: $name, phone: $phone, balance: $currentBalance, active: $isActive)';
}
