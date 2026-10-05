import 'package:sales/core/domain/entities/entity.dart';
import 'sales_return_item.dart';

/// كيان مرتجع المبيعات (Sales Return)
class SalesReturn extends Entity {
  final int id;
  final String returnNumber;
  final int salesInvoiceId;
  final String? salesInvoiceNumber;
  final int? customerId;
  final String? customerName;
  final DateTime returnDate;
  final int total;
  final int refundAmount;
  final int debtReductionAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final List<SalesReturnItem> items;

  const SalesReturn({
    required this.id,
    required this.returnNumber,
    required this.salesInvoiceId,
    this.salesInvoiceNumber,
    this.customerId,
    this.customerName,
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
      other is SalesReturn &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  SalesReturn copyWith({
    int? id,
    String? returnNumber,
    int? salesInvoiceId,
    String? salesInvoiceNumber,
    int? customerId,
    String? customerName,
    DateTime? returnDate,
    int? total,
    int? refundAmount,
    int? debtReductionAmount,
    String? status,
    String? notes,
    DateTime? createdAt,
    List<SalesReturnItem>? items,
  }) {
    return SalesReturn(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      salesInvoiceId: salesInvoiceId ?? this.salesInvoiceId,
      salesInvoiceNumber: salesInvoiceNumber ?? this.salesInvoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
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
