/// سطر تقرير ديون العميل
class CustomerDebtReportRow {
  final int id;
  final String name;
  final String? phone;
  final int creditSalesTotal;
  final int paidTotal;
  final int returnsTotal;
  final int remainingBalance;
  final DateTime? lastActivityDate;

  const CustomerDebtReportRow({
    required this.id,
    required this.name,
    this.phone,
    required this.creditSalesTotal,
    required this.paidTotal,
    required this.returnsTotal,
    required this.remainingBalance,
    this.lastActivityDate,
  });
}

/// سطر تقرير ديون المورد
class SupplierDebtReportRow {
  final int id;
  final String name;
  final String? phone;
  final int creditPurchasesTotal;
  final int paidTotal;
  final int returnsTotal;
  final int remainingBalance;
  final DateTime? lastActivityDate;

  const SupplierDebtReportRow({
    required this.id,
    required this.name,
    this.phone,
    required this.creditPurchasesTotal,
    required this.paidTotal,
    required this.returnsTotal,
    required this.remainingBalance,
    this.lastActivityDate,
  });
}

/// بيانات تقرير الديون الشامل (العملاء والموردين)
class DebtsReportData {
  final int totalCustomerDebt;
  final int totalSupplierDebt;
  final int netDebt; // ديون العملاء (لنا) - ديون الموردين (علينا)
  final List<CustomerDebtReportRow> customerDebts;
  final List<SupplierDebtReportRow> supplierDebts;

  const DebtsReportData({
    required this.totalCustomerDebt,
    required this.totalSupplierDebt,
    required this.netDebt,
    required this.customerDebts,
    required this.supplierDebts,
  });

  factory DebtsReportData.empty() {
    return const DebtsReportData(
      totalCustomerDebt: 0,
      totalSupplierDebt: 0,
      netDebt: 0,
      customerDebts: [],
      supplierDebts: [],
    );
  }
}
