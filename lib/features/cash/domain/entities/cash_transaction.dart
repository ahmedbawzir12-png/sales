import 'cash_flow_direction.dart';
import 'cash_transaction_type.dart';

/// كيان حركة الصندوق النقدي (CashTransaction)
/// يمثل سجل الحركات النقدية الفعلي وهو مصدر الحقيقة الوحيد لرصيد الصندوق
class CashTransaction {
  final int id;
  final CashTransactionType type;
  final CashFlowDirection direction;
  final int amount;
  final DateTime transactionDate;
  final String? referenceType;
  final int? referenceId;
  final String description;
  final String? notes;
  final DateTime createdAt;

  /// الرصيد التراكمي المحسوب بعد هذه الحركة (لأغراض العرض فقط في الكشف)
  final int? runningBalance;

  const CashTransaction({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.transactionDate,
    this.referenceType,
    this.referenceId,
    required this.description,
    this.notes,
    required this.createdAt,
    this.runningBalance,
  });

  CashTransaction copyWith({
    int? id,
    CashTransactionType? type,
    CashFlowDirection? direction,
    int? amount,
    DateTime? transactionDate,
    String? referenceType,
    int? referenceId,
    String? description,
    String? notes,
    DateTime? createdAt,
    int? runningBalance,
  }) {
    return CashTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      runningBalance: runningBalance ?? this.runningBalance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CashTransaction(id: $id, type: ${type.name}, dir: ${direction.name}, amount: $amount, desc: $description)';
}
