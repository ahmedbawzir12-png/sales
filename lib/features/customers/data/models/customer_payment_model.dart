import '../../domain/entities/customer_payment.dart';

class CustomerPaymentModel {
  final int id;
  final String paymentNumber;
  final int customerId;
  final String? customerName;
  final int amount;
  final String paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final String createdAt;

  const CustomerPaymentModel({
    required this.id,
    required this.paymentNumber,
    required this.customerId,
    this.customerName,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory CustomerPaymentModel.fromMap(Map<String, dynamic> map) {
    return CustomerPaymentModel(
      id: (map['id'] as num).toInt(),
      paymentNumber: map['payment_number'] as String,
      customerId: (map['customer_id'] as num).toInt(),
      customerName: map['customer_name'] as String?,
      amount: (map['amount'] as num).toInt(),
      paymentDate: map['payment_date'] as String,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'payment_number': paymentNumber,
      'customer_id': customerId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  CustomerPayment toEntity() {
    return CustomerPayment(
      id: id,
      paymentNumber: paymentNumber,
      customerId: customerId,
      customerName: customerName,
      amount: amount,
      paymentDate: DateTime.parse(paymentDate),
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
    );
  }

  factory CustomerPaymentModel.fromEntity(CustomerPayment entity) {
    return CustomerPaymentModel(
      id: entity.id,
      paymentNumber: entity.paymentNumber,
      customerId: entity.customerId,
      customerName: entity.customerName,
      amount: entity.amount,
      paymentDate: entity.paymentDate.toIso8601String(),
      paymentMethod: entity.paymentMethod,
      reference: entity.reference,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
