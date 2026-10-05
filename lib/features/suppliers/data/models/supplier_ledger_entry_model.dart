import '../../domain/entities/supplier_ledger_entry.dart';

class SupplierLedgerEntryModel {
  final int id;
  final int supplierId;
  final String transactionType;
  final int amount;
  final String transactionDate;
  final String referenceType;
  final int referenceId;
  final String? notes;
  final String createdAt;

  const SupplierLedgerEntryModel({
    required this.id,
    required this.supplierId,
    required this.transactionType,
    required this.amount,
    required this.transactionDate,
    required this.referenceType,
    required this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory SupplierLedgerEntryModel.fromMap(Map<String, dynamic> map) {
    return SupplierLedgerEntryModel(
      id: (map['id'] as num).toInt(),
      supplierId: (map['supplier_id'] as num).toInt(),
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
      'supplier_id': supplierId,
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

  SupplierLedgerEntry toEntity() {
    SupplierLedgerTransactionType type;
    switch (transactionType) {
      case 'purchase_credit':
        type = SupplierLedgerTransactionType.purchaseCredit;
        break;
      case 'payment':
        type = SupplierLedgerTransactionType.payment;
        break;
      case 'purchase_return':
        type = SupplierLedgerTransactionType.purchaseReturn;
        break;
      case 'cancellation':
        type = SupplierLedgerTransactionType.cancellation;
        break;
      case 'adjustment':
      default:
        type = SupplierLedgerTransactionType.adjustment;
        break;
    }

    return SupplierLedgerEntry(
      id: id,
      supplierId: supplierId,
      transactionType: type,
      amount: amount,
      transactionDate: DateTime.parse(transactionDate),
      referenceType: referenceType,
      referenceId: referenceId,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
    );
  }

  static String mapTransactionType(SupplierLedgerTransactionType type) {
    switch (type) {
      case SupplierLedgerTransactionType.purchaseCredit:
        return 'purchase_credit';
      case SupplierLedgerTransactionType.payment:
        return 'payment';
      case SupplierLedgerTransactionType.purchaseReturn:
        return 'purchase_return';
      case SupplierLedgerTransactionType.cancellation:
        return 'cancellation';
      case SupplierLedgerTransactionType.adjustment:
        return 'adjustment';
    }
  }

  factory SupplierLedgerEntryModel.fromEntity(SupplierLedgerEntry entity) {
    return SupplierLedgerEntryModel(
      id: entity.id,
      supplierId: entity.supplierId,
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
