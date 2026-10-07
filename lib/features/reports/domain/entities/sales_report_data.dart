import 'date_range.dart';

/// سطر فاتورة في جدول تقرير المبيعات
class SalesInvoiceReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? customerName;
  final int total;
  final int paidAmount;
  final int remainingAmount;
  final String paymentType;
  final String status;

  const SalesInvoiceReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.customerName,
    required this.total,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentType,
    required this.status,
  });

  bool get isPaid => remainingAmount == 0;
  bool get isCredit => paymentType == 'credit';
}

/// بيانات تقرير المبيعات المكتمل للفترة المحددة
class SalesReportData {
  final DateRange dateRange;
  final int invoiceCount;
  final int grossSales;
  final int discountTotal;
  final int returnsTotal;
  final int netSales;
  final int cashPaidTotal;
  final int creditSalesTotal;
  final int remainingDebtTotal;
  final double averageInvoiceValue;
  final List<SalesInvoiceReportRow> invoices;

  const SalesReportData({
    required this.dateRange,
    required this.invoiceCount,
    required this.grossSales,
    required this.discountTotal,
    required this.returnsTotal,
    required this.netSales,
    required this.cashPaidTotal,
    required this.creditSalesTotal,
    required this.remainingDebtTotal,
    required this.averageInvoiceValue,
    required this.invoices,
  });

  factory SalesReportData.empty(DateRange range) {
    return SalesReportData(
      dateRange: range,
      invoiceCount: 0,
      grossSales: 0,
      discountTotal: 0,
      returnsTotal: 0,
      netSales: 0,
      cashPaidTotal: 0,
      creditSalesTotal: 0,
      remainingDebtTotal: 0,
      averageInvoiceValue: 0.0,
      invoices: const [],
    );
  }
}
