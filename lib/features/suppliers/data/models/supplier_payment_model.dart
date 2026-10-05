import '../../domain/entities/supplier_payment.dart';

class SupplierPaymentModel {
  final int id;
  final String paymentNumber;
  final int supplierId;
  final String? supplierName;
  final int amount;
  final String paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final String createdAt;

  const SupplierPaymentModel({
    required this.id,
    required this.paymentNumber,
    required this.supplierId,
    this.supplierName,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory SupplierPaymentModel.fromMap(Map<String, dynamic> map) {
    return SupplierPaymentModel(
      id: (map['id'] as num).toInt(),
      paymentNumber: map['payment_number'] as String,
      supplierId: (map['supplier_id'] as num).toInt(),
      supplierName: map['supplier_name'] as String?,
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
      'supplier_id': supplierId,
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

  SupplierPayment toEntity() {
    return SupplierPayment(
      id: id,
      paymentNumber: paymentNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      amount: amount,
      paymentDate: DateTime.parse(paymentDate),
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
    );
  }

  factory SupplierPaymentModel.fromEntity(SupplierPayment entity) {
    return SupplierPaymentModel(
      id: entity.id,
      paymentNumber: entity.paymentNumber,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      amount: entity.amount,
      paymentDate: entity.paymentDate.toIso8601String(),
      paymentMethod: entity.paymentMethod,
      reference: entity.reference,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
