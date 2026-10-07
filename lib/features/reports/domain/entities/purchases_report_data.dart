import 'date_range.dart';

/// سطر فاتورة في جدول تقرير المشتريات
class PurchaseInvoiceReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? supplierName;
  final int total;
  final int paidAmount;
  final int remainingAmount;
  final String paymentType;
  final String status;

  const PurchaseInvoiceReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.supplierName,
    required this.total,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentType,
    required this.status,
  });

  bool get isPaid => remainingAmount == 0;
  bool get isCredit => paymentType == 'credit';
}

/// بيانات تقرير المشتريات للفترة المحددة
class PurchasesReportData {
  final DateRange dateRange;
  final int invoiceCount;
  final int grossPurchases;
  final int discountTotal;
  final int returnsTotal;
  final int netPurchases;
  final int cashPaidTotal;
  final int creditPurchasesTotal;
  final int remainingDebtTotal;
  final double averageInvoiceValue;
  final List<PurchaseInvoiceReportRow> invoices;

  const PurchasesReportData({
    required this.dateRange,
    required this.invoiceCount,
    required this.grossPurchases,
    required this.discountTotal,
    required this.returnsTotal,
    required this.netPurchases,
    required this.cashPaidTotal,
    required this.creditPurchasesTotal,
    required this.remainingDebtTotal,
    required this.averageInvoiceValue,
    required this.invoices,
  });

  factory PurchasesReportData.empty(DateRange range) {
    return PurchasesReportData(
      dateRange: range,
      invoiceCount: 0,
      grossPurchases: 0,
      discountTotal: 0,
      returnsTotal: 0,
      netPurchases: 0,
      cashPaidTotal: 0,
      creditPurchasesTotal: 0,
      remainingDebtTotal: 0,
      averageInvoiceValue: 0.0,
      invoices: const [],
    );
  }
}
