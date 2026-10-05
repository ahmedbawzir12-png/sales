import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_invoice_item.dart';
import '../../domain/entities/sales_invoice_status.dart';
import '../../domain/entities/sales_payment_type.dart';

/// نموذج فاتورة المبيعات للتحويل والتخزين في SQLite
class SalesInvoiceModel {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final String invoiceDate;
  final int subtotal;
  final int discount;
  final int total;
  final int paidAmount;
  final int remainingAmount;
  final String paymentType;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // حقل مساند للعرض
  final String? customerName;

  const SalesInvoiceModel({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.invoiceDate,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    required this.paymentType,
    this.status = 'completed',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
  });

  factory SalesInvoiceModel.fromEntity(SalesInvoice entity) {
    return SalesInvoiceModel(
      id: entity.id == 0 ? null : entity.id,
      invoiceNumber: entity.invoiceNumber,
      customerId: entity.customerId,
      invoiceDate: entity.invoiceDate.toIso8601String(),
      subtotal: entity.subtotal,
      discount: entity.discount,
      total: entity.totalAmount,
      paidAmount: entity.paidAmount,
      remainingAmount: entity.remainingAmount,
      paymentType: entity.paymentType.name,
      status: entity.status.name,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
      customerName: entity.customerName,
    );
  }

  SalesInvoice toEntity({List<SalesInvoiceItem> items = const []}) {
    return SalesInvoice(
      id: id ?? 0,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      invoiceDate: DateTime.parse(invoiceDate),
      subtotal: subtotal,
      discount: discount,
      totalAmount: total,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      paymentType: SalesPaymentType.fromString(paymentType),
      status: SalesInvoiceStatus.fromString(status),
      notes: notes,
      items: items,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      customerName: customerName,
    );
  }

  factory SalesInvoiceModel.fromMap(Map<String, dynamic> map) {
    return SalesInvoiceModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as int?,
      invoiceDate: map['invoice_date'] as String,
      subtotal: (map['subtotal'] as num).toInt(),
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num).toInt(),
      paidAmount: (map['paid_amount'] as num?)?.toInt() ?? 0,
      remainingAmount: (map['remaining_amount'] as num?)?.toInt() ?? 0,
      paymentType: map['payment_type'] as String,
      status: map['status'] as String? ?? 'completed',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      customerName: map['customer_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'invoice_date': invoiceDate,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'payment_type': paymentType,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
