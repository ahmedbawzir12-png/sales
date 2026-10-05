import 'package:sales/core/domain/entities/entity.dart';
import 'purchase_return_item.dart';

/// كيان مرتجع المشتريات (Purchase Return)
class PurchaseReturn extends Entity {
  final int id;
  final String returnNumber;
  final int purchaseInvoiceId;
  final String? purchaseInvoiceNumber;
  final int supplierId;
  final String? supplierName;
  final DateTime returnDate;
  final int total;
  final int refundAmount;
  final int debtReductionAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseReturnItem> items;

  const PurchaseReturn({
    required this.id,
    required this.returnNumber,
    required this.purchaseInvoiceId,
    this.purchaseInvoiceNumber,
    required this.supplierId,
    this.supplierName,
    required this.returnDate,
    required this.total,
    this.refundAmount = 0,
    this.debtReductionAmount = 0,
    this.status = 'completed',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseReturn &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  PurchaseReturn copyWith({
    int? id,
    String? returnNumber,
    int? purchaseInvoiceId,
    String? purchaseInvoiceNumber,
    int? supplierId,
    String? supplierName,
    DateTime? returnDate,
    int? total,
    int? refundAmount,
    int? debtReductionAmount,
    String? status,
    String? notes,
    DateTime? createdAt,
    List<PurchaseReturnItem>? items,
  }) {
    return PurchaseReturn(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
      purchaseInvoiceNumber:
          purchaseInvoiceNumber ?? this.purchaseInvoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      returnDate: returnDate ?? this.returnDate,
      total: total ?? this.total,
      refundAmount: refundAmount ?? this.refundAmount,
      debtReductionAmount: debtReductionAmount ?? this.debtReductionAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
