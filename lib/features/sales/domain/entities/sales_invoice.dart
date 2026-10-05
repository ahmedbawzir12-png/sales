import 'package:sales/core/domain/entities/entity.dart';
import 'sales_invoice_item.dart';
import 'sales_invoice_status.dart';
import 'sales_payment_type.dart';

/// كيان فاتورة المبيعات في طبقة النطاق
class SalesInvoice extends Entity {
  final int id;
  final String invoiceNumber;
  final int? customerId; // null للعمليات النقدية العامة للزبائن العاديين
  final DateTime invoiceDate;
  final int subtotal; // إجمالي البنود قبل الخصم
  final int discount; // الخصم الإجمالي على الفاتورة
  final int totalAmount; // الصافي النهائي للفاتورة
  final int paidAmount; // المبلغ المقبوض نقداً
  final int remainingAmount; // المبلغ المتبقي كدين على العميل
  final SalesPaymentType paymentType;
  final SalesInvoiceStatus status;
  final String? notes;
  final List<SalesInvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  // حقل مساعد للعرض
  final String? customerName;

  const SalesInvoice({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.invoiceDate,
    required this.subtotal,
    this.discount = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.paymentType = SalesPaymentType.cash,
    this.status = SalesInvoiceStatus.completed,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
  });

  /// هل الفاتورة مسددة بالكامل؟
  bool get isFullyPaid => remainingAmount == 0;

  /// هل الفاتورة ملغاة؟
  bool get isCancelled => status == SalesInvoiceStatus.cancelled;

  /// إجمالي التكلفة التاريخية لجميع بنود الفاتورة
  double get totalCostAtSale =>
      items.fold(0.0, (sum, item) => sum + item.costTotal);

  /// إجمالي الربح المقدر للفاتورة
  double get grossProfit => totalAmount - totalCostAtSale;

  SalesInvoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    DateTime? invoiceDate,
    int? subtotal,
    int? discount,
    int? totalAmount,
    int? paidAmount,
    int? remainingAmount,
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    String? notes,
    List<SalesInvoiceItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
  }) {
    return SalesInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          invoiceNumber == other.invoiceNumber;

  @override
  int get hashCode => id != 0 ? id.hashCode : invoiceNumber.hashCode;

  @override
  String toString() =>
      'SalesInvoice(id: $id, number: $invoiceNumber, total: $totalAmount, paid: $paidAmount, remaining: $remainingAmount, status: ${status.name})';
}
