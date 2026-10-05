import '../../domain/entities/sales_return.dart';
import '../../domain/entities/sales_return_item.dart';

class SalesReturnModel {
  final int id;
  final String returnNumber;
  final int salesInvoiceId;
  final String? salesInvoiceNumber;
  final int? customerId;
  final String? customerName;
  final String returnDate;
  final int total;
  final int refundAmount;
  final int debtReductionAmount;
  final String status;
  final String? notes;
  final String createdAt;

  const SalesReturnModel({
    required this.id,
    required this.returnNumber,
    required this.salesInvoiceId,
    this.salesInvoiceNumber,
    this.customerId,
    this.customerName,
    required this.returnDate,
    required this.total,
    required this.refundAmount,
    required this.debtReductionAmount,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory SalesReturnModel.fromMap(Map<String, dynamic> map) {
    return SalesReturnModel(
      id: (map['id'] as num).toInt(),
      returnNumber: map['return_number'] as String,
      salesInvoiceId: (map['sales_invoice_id'] as num).toInt(),
      salesInvoiceNumber: map['invoice_number'] as String?,
      customerId: (map['customer_id'] as num?)?.toInt(),
      customerName: map['customer_name'] as String?,
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
      'sales_invoice_id': salesInvoiceId,
      'customer_id': customerId,
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

  SalesReturn toEntity({List<SalesReturnItem> items = const []}) {
    return SalesReturn(
      id: id,
      returnNumber: returnNumber,
      salesInvoiceId: salesInvoiceId,
      salesInvoiceNumber: salesInvoiceNumber,
      customerId: customerId,
      customerName: customerName,
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

  factory SalesReturnModel.fromEntity(SalesReturn entity) {
    return SalesReturnModel(
      id: entity.id,
      returnNumber: entity.returnNumber,
      salesInvoiceId: entity.salesInvoiceId,
      salesInvoiceNumber: entity.salesInvoiceNumber,
      customerId: entity.customerId,
      customerName: entity.customerName,
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
