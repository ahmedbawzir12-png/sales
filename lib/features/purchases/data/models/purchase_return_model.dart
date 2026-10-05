import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';

class PurchaseReturnModel {
  final int id;
  final String returnNumber;
  final int purchaseInvoiceId;
  final String? purchaseInvoiceNumber;
  final int supplierId;
  final String? supplierName;
  final String returnDate;
  final int total;
  final int refundAmount;
  final int debtReductionAmount;
  final String status;
  final String? notes;
  final String createdAt;

  const PurchaseReturnModel({
    required this.id,
    required this.returnNumber,
    required this.purchaseInvoiceId,
    this.purchaseInvoiceNumber,
    required this.supplierId,
    this.supplierName,
    required this.returnDate,
    required this.total,
    required this.refundAmount,
    required this.debtReductionAmount,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory PurchaseReturnModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnModel(
      id: (map['id'] as num).toInt(),
      returnNumber: map['return_number'] as String,
      purchaseInvoiceId: (map['purchase_invoice_id'] as num).toInt(),
      purchaseInvoiceNumber: map['invoice_number'] as String?,
      supplierId: (map['supplier_id'] as num).toInt(),
      supplierName: map['supplier_name'] as String?,
      returnDate: map['return_date'] as String,
      total: (map['total'] as num).toInt(),
      refundAmount: (map['refund_amount'] as num?)?.toInt() ?? 0,
      debtReductionAmount:
          (map['debt_reduction_amount'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'completed',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'return_number': returnNumber,
      'purchase_invoice_id': purchaseInvoiceId,
      'supplier_id': supplierId,
      'return_date': returnDate,
      'total': total,
      'refund_amount': refundAmount,
      'debt_reduction_amount': debtReductionAmount,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  PurchaseReturn toEntity({List<PurchaseReturnItem> items = const []}) {
    return PurchaseReturn(
      id: id,
      returnNumber: returnNumber,
      purchaseInvoiceId: purchaseInvoiceId,
      purchaseInvoiceNumber: purchaseInvoiceNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      returnDate: DateTime.parse(returnDate),
      total: total,
      refundAmount: refundAmount,
      debtReductionAmount: debtReductionAmount,
      status: status,
      notes: notes,
      createdAt: DateTime.parse(createdAt),
      items: items,
    );
  }

  factory PurchaseReturnModel.fromEntity(PurchaseReturn entity) {
    return PurchaseReturnModel(
      id: entity.id,
      returnNumber: entity.returnNumber,
      purchaseInvoiceId: entity.purchaseInvoiceId,
      purchaseInvoiceNumber: entity.purchaseInvoiceNumber,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      returnDate: entity.returnDate.toIso8601String(),
      total: entity.total,
      refundAmount: entity.refundAmount,
      debtReductionAmount: entity.debtReductionAmount,
      status: entity.status,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
