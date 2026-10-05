import 'package:sales/core/domain/entities/entity.dart';

/// أنواع الحركات المالية في أستاذ العميل
enum CustomerLedgerTransactionType {
  /// بيع آجل (يزيد دين العميل)
  saleCredit,

  /// دفعة مسددة من العميل (تخفض دين العميل)
  payment,

  /// مرتجع مبيعات مؤثر على الدين (يخفض دين العميل)
  salesReturn,

  /// إلغاء فاتورة بيع آجلة (يخفض دين العميل)
  cancellation,

  /// تسوية رصيد
  adjustment;

  String get arabicLabel {
    switch (this) {
      case CustomerLedgerTransactionType.saleCredit:
        return 'فاتورة مبيعات آجلة';
      case CustomerLedgerTransactionType.payment:
        return 'سداد دفعة';
      case CustomerLedgerTransactionType.salesReturn:
        return 'مرتجع مبيعات';
      case CustomerLedgerTransactionType.cancellation:
        return 'إلغاء فاتورة';
      case CustomerLedgerTransactionType.adjustment:
        return 'تسوية حساب';
    }
  }

  /// هل تؤدي الحركة لزيادة الدين المستحق على العميل؟
  bool get isDebtIncrease => this == CustomerLedgerTransactionType.saleCredit;
}

/// كيان حركة أستاذ العميل (Customer Ledger Entry)
class CustomerLedgerEntry extends Entity {
  final int id;
  final int customerId;
  final CustomerLedgerTransactionType transactionType;
  final int amount;
  final DateTime transactionDate;
  final String referenceType;
  final int referenceId;
  final String? notes;
  final DateTime createdAt;

  const CustomerLedgerEntry({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerLedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  CustomerLedgerEntry copyWith({
    int? id,
    int? customerId,
    CustomerLedgerTransactionType? transactionType,
    int? amount,
    DateTime? transactionDate,
    String? referenceType,
    int? referenceId,
    String? notes,
    DateTime? createdAt,
  }) {
    return CustomerLedgerEntry(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
