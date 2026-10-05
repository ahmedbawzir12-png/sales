import 'package:sales/core/domain/entities/entity.dart';

/// أنواع الحركات المالية في أستاذ المورد
enum SupplierLedgerTransactionType {
  /// شراء آجل (يزيد مستحقات المورد / دين المحل للمورد)
  purchaseCredit,

  /// دفعة مسددة للمورد (تخفض دين المورد)
  payment,

  /// مرتجع مشتريات مؤثر على الدين (يخفض دين المورد)
  purchaseReturn,

  /// إلغاء فاتورة شراء آجلة (يخفض دين المورد)
  cancellation,

  /// تسوية رصيد
  adjustment;

  String get arabicLabel {
    switch (this) {
      case SupplierLedgerTransactionType.purchaseCredit:
        return 'فاتورة مشتريات آجلة';
      case SupplierLedgerTransactionType.payment:
        return 'سداد دفعة للمورد';
      case SupplierLedgerTransactionType.purchaseReturn:
        return 'مرتجع مشتريات';
      case SupplierLedgerTransactionType.cancellation:
        return 'إلغاء فاتورة مشتريات';
      case SupplierLedgerTransactionType.adjustment:
        return 'تسوية حساب مورد';
    }
  }

  /// هل تؤدي الحركة لزيادة الدين المستحق للمورد؟
  bool get isDebtIncrease =>
      this == SupplierLedgerTransactionType.purchaseCredit;
}

/// كيان حركة أستاذ المورد (Supplier Ledger Entry)
class SupplierLedgerEntry extends Entity {
  final int id;
  final int supplierId;
  final SupplierLedgerTransactionType transactionType;
  final int amount;
  final DateTime transactionDate;
  final String referenceType;
  final int referenceId;
  final String? notes;
  final DateTime createdAt;

  const SupplierLedgerEntry({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierLedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  SupplierLedgerEntry copyWith({
    int? id,
    int? supplierId,
    SupplierLedgerTransactionType? transactionType,
    int? amount,
    DateTime? transactionDate,
    String? referenceType,
    int? referenceId,
    String? notes,
    DateTime? createdAt,
  }) {
    return SupplierLedgerEntry(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
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
