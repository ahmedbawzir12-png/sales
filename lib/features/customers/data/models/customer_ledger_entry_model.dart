import '../../domain/entities/customer_ledger_entry.dart';

class CustomerLedgerEntryModel {
  final int id;
  final int customerId;
  final String transactionType;
  final int amount;
  final String transactionDate;
  final String referenceType;
  final int referenceId;
  final String? notes;
  final String createdAt;

  const CustomerLedgerEntryModel({
    required this.id,
    required this.customerId,
    required this.transactionType,
    required this.amount,
    required this.transactionDate,
    required this.referenceType,
    required this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory CustomerLedgerEntryModel.fromMap(Map<String, dynamic> map) {
    return CustomerLedgerEntryModel(
      id: (map['id'] as num).toInt(),
      customerId: (map['customer_id'] as num).toInt(),
      transactionType: map['transaction_type'] as String,
      amount: (map['amount'] as num).toInt(),
      transactionDate: map['transaction_date'] as String,
      referenceType: map['reference_type'] as String,
      referenceId: (map['reference_id'] as num).toInt(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'customer_id': customerId,
      'transaction_type': transactionType,
      'amount': amount,
      'transaction_date': transactionDate,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  CustomerLedgerEntry toEntity() {
    CustomerLedgerTransactionType type;
    switch (transactionType) {
      case 'sale_credit':
        type = CustomerLedgerTransactionType.saleCredit;
        break;
      case 'payment':
        type = CustomerLedgerTransactionType.payment;
        break;
      case 'sales_return':
        type = CustomerLedgerTransactionType.salesReturn;
        break;
      case 'cancellation':
        type = CustomerLedgerTransactionType.cancellation;
        break;
      case 'adjustment':
      default:
        type = CustomerLedgerTransactionType.adjustment;
        break;
    }

    return CustomerLedgerEntry(
      id: id,
      customerId: customerId,
      transactionType: type,
      amount: amount,
      transactionDate: DateTime.parse(transactionDate),
      referenceType: referenceType,
      referenceId: referenceId,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
    );
  }

  static String mapTransactionType(CustomerLedgerTransactionType type) {
    switch (type) {
      case CustomerLedgerTransactionType.saleCredit:
        return 'sale_credit';
      case CustomerLedgerTransactionType.payment:
        return 'payment';
      case CustomerLedgerTransactionType.salesReturn:
        return 'sales_return';
      case CustomerLedgerTransactionType.cancellation:
        return 'cancellation';
      case CustomerLedgerTransactionType.adjustment:
        return 'adjustment';
    }
  }

  factory CustomerLedgerEntryModel.fromEntity(CustomerLedgerEntry entity) {
    return CustomerLedgerEntryModel(
      id: entity.id,
      customerId: entity.customerId,
      transactionType: mapTransactionType(entity.transactionType),
      amount: entity.amount,
      transactionDate: entity.transactionDate.toIso8601String(),
      referenceType: entity.referenceType,
      referenceId: entity.referenceId,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
