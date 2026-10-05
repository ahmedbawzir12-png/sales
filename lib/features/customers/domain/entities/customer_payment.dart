import 'package:sales/core/domain/entities/entity.dart';

/// كيان دفعة العميل المالية (Customer Payment)
class CustomerPayment extends Entity {
  final int id;
  final String paymentNumber;
  final int customerId;
  final String? customerName;
  final int amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  const CustomerPayment({
    required this.id,
    required this.paymentNumber,
    required this.customerId,
    this.customerName,
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
      other is CustomerPayment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  CustomerPayment copyWith({
    int? id,
    String? paymentNumber,
    int? customerId,
    String? customerName,
    int? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
    DateTime? createdAt,
  }) {
    return CustomerPayment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
