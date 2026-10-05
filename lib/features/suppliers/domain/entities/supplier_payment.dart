import 'package:sales/core/domain/entities/entity.dart';

/// كيان دفعة المورد المالية (Supplier Payment)
class SupplierPayment extends Entity {
  final int id;
  final String paymentNumber;
  final int supplierId;
  final String? supplierName;
  final int amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  const SupplierPayment({
    required this.id,
    required this.paymentNumber,
    required this.supplierId,
    this.supplierName,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'cash',
    this.reference,
    this.notes,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierPayment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  SupplierPayment copyWith({
    int? id,
    String? paymentNumber,
    int? supplierId,
    String? supplierName,
    int? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
    DateTime? createdAt,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
