import 'package:sales/core/domain/entities/entity.dart';
import 'purchase_invoice_item.dart';
import 'purchase_invoice_status.dart';
import 'purchase_payment_type.dart';

/// كيان فاتورة الشراء في طبقة النطاق
class PurchaseInvoice extends Entity {
  final int id;
  final String invoiceNumber;
  final int supplierId;
  final DateTime invoiceDate;
  final int subtotal;
  final int discount;
  final int total;
  final int paidAmount;
  final int remainingAmount;
  final PurchasePaymentType paymentType;
  final PurchaseInvoiceStatus status;
  final String? notes;
  final List<PurchaseInvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  // حقول مساعدة للعرض
  final String? supplierName;
  final String? supplierPhone;

  const PurchaseInvoice({
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
    this.status = PurchaseInvoiceStatus.completed,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.supplierPhone,
  });

  /// هل الفاتورة مسددة بالكامل؟
  bool get isPaidInFull => remainingAmount <= 0;

  /// هل الفاتورة ملغاة؟
  bool get isCancelled => status == PurchaseInvoiceStatus.cancelled;

  PurchaseInvoice copyWith({
    int? id,
    String? invoiceNumber,
    int? supplierId,
    DateTime? invoiceDate,
    int? subtotal,
    int? discount,
    int? total,
    int? paidAmount,
    int? remainingAmount,
    PurchasePaymentType? paymentType,
    PurchaseInvoiceStatus? status,
    String? notes,
    List<PurchaseInvoiceItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? supplierPhone,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseInvoice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          invoiceNumber == other.invoiceNumber &&
          supplierId == other.supplierId &&
          total == other.total &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        invoiceNumber,
        supplierId,
        total,
        status,
      );

  @override
  String toString() =>
      'PurchaseInvoice(id: $id, number: $invoiceNumber, total: $total, status: ${status.arabicLabel})';
}
