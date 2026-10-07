import '../../domain/entities/cash_flow_direction.dart';
import '../../domain/entities/cash_transaction.dart';
import '../../domain/entities/cash_transaction_type.dart';

/// نموذج بيانات حركة الصندوق في طبقة البيانات
class CashTransactionModel {
  final int id;
  final String transactionType;
  final String direction;
  final int amount;
  final String transactionDate;
  final String? referenceType;
  final int? referenceId;
  final String description;
  final String? notes;
  final String createdAt;

  const CashTransactionModel({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.amount,
    required this.transactionDate,
    this.referenceType,
    this.referenceId,
    required this.description,
    this.notes,
    required this.createdAt,
  });

  factory CashTransactionModel.fromMap(Map<String, dynamic> map) {
    return CashTransactionModel(
      id: map['id'] as int? ?? 0,
      transactionType: map['transaction_type'] as String,
      direction: map['direction'] as String,
      amount: map['amount'] as int,
      transactionDate: map['transaction_date'] as String,
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as int?,
      description: map['description'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transaction_type': transactionType,
      'direction': direction,
      'amount': amount,
      'transaction_date': transactionDate,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'notes': notes,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  CashTransaction toEntity({int? runningBalance}) {
    final typeEnum = CashTransactionType.values.firstWhere(
      (e) => e.name == transactionType,
      orElse: () => CashTransactionType.adjustment,
    );

    final dirEnum = CashFlowDirection.values.firstWhere(
      (e) => e.name == direction,
      orElse: () => CashFlowDirection.cashIn,
    );

    return CashTransaction(
      id: id,
      type: typeEnum,
      direction: dirEnum,
      amount: amount,
      transactionDate: DateTime.parse(transactionDate),
      referenceType: referenceType,
      referenceId: referenceId,
      description: description,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
      runningBalance: runningBalance,
    );
  }

  factory CashTransactionModel.fromEntity(CashTransaction entity) {
    return CashTransactionModel(
      id: entity.id,
      transactionType: entity.type.name,
      direction: entity.direction.name,
      amount: entity.amount,
      transactionDate: entity.transactionDate.toIso8601String(),
      referenceType: entity.referenceType,
      referenceId: entity.referenceId,
      description: entity.description,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
