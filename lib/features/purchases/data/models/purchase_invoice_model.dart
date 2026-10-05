import 'package:sales/core/data/models/data_model.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_item.dart';
import '../../domain/entities/purchase_invoice_status.dart';
import '../../domain/entities/purchase_payment_type.dart';

/// نموذج بيانات رأس فاتورة الشراء لـ SQLite
class PurchaseInvoiceModel extends DataModel<PurchaseInvoice> {
  final int id;
  final String invoiceNumber;
  final int supplierId;
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

  // حقول منضمّة من جدول الموردين
  final String? supplierName;
  final String? supplierPhone;

  const PurchaseInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.supplierId,
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
    this.supplierName,
    this.supplierPhone,
  });

  factory PurchaseInvoiceModel.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceModel(
      id: map['id'] as int? ?? 0,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      supplierId: map['supplier_id'] as int? ?? 0,
      invoiceDate: map['invoice_date'] as String? ?? DateTime.now().toIso8601String(),
      subtotal: map['subtotal'] as int? ?? 0,
      discount: map['discount'] as int? ?? 0,
      total: map['total'] as int? ?? 0,
      paidAmount: map['paid_amount'] as int? ?? 0,
      remainingAmount: map['remaining_amount'] as int? ?? 0,
      paymentType: map['payment_type'] as String? ?? 'cash',
      status: map['status'] as String? ?? 'completed',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      supplierName: map['supplier_name'] as String?,
      supplierPhone: map['supplier_phone'] as String?,
    );
  }

  factory PurchaseInvoiceModel.fromEntity(PurchaseInvoice entity) {
    return PurchaseInvoiceModel(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      supplierId: entity.supplierId,
      invoiceDate: entity.invoiceDate.toIso8601String(),
      subtotal: entity.subtotal,
      discount: entity.discount,
      total: entity.total,
      paidAmount: entity.paidAmount,
      remainingAmount: entity.remainingAmount,
      paymentType: entity.paymentType.name,
      status: entity.status.name,
      notes: entity.notes,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
      supplierName: entity.supplierName,
      supplierPhone: entity.supplierPhone,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
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
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }

  @override
  PurchaseInvoice toEntity([List<PurchaseInvoiceItem> items = const []]) {
    return PurchaseInvoice(
      id: id,
      invoiceNumber: invoiceNumber,
      supplierId: supplierId,
      invoiceDate: DateTime.tryParse(invoiceDate) ?? DateTime.now(),
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      paymentType: PurchasePaymentType.fromString(paymentType),
      status: PurchaseInvoiceStatus.fromString(status),
      notes: notes,
      items: items,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
      supplierName: supplierName,
      supplierPhone: supplierPhone,
    );
  }
}
