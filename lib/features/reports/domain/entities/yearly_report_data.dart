/// سطر ملخص الشهر في التقرير السنوي
class MonthlyProfitRow {
  final int monthNumber;
  final String monthName;
  final int grossSales;
  final int salesReturns;
  final int netSales;
  final double netCogs;
  final double grossProfit;
  final int expenses;
  final double netProfit;

  const MonthlyProfitRow({
    required this.monthNumber,
    required this.monthName,
    required this.grossSales,
    required this.salesReturns,
    required this.netSales,
    required this.netCogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
  });
}

/// بيانات التقرير السنوي الشامل مع التفصيل الشهري
class YearlyReportData {
  final int year;
  final int totalGrossSales;
  final int totalSalesReturns;
  final int netSales;
  final double totalNetCogs;
  final double totalGrossProfit;
  final int totalExpenses;
  final double totalNetProfit;
  final List<MonthlyProfitRow> monthlyBreakdown;

  const YearlyReportData({
    required this.year,
    required this.totalGrossSales,
    required this.totalSalesReturns,
    required this.netSales,
    required this.totalNetCogs,
    required this.totalGrossProfit,
    required this.totalExpenses,
    required this.totalNetProfit,
    required this.monthlyBreakdown,
  });

  factory YearlyReportData.empty(int year) {
    return YearlyReportData(
      year: year,
      totalGrossSales: 0,
      totalSalesReturns: 0,
      netSales: 0,
      totalNetCogs: 0.0,
      totalGrossProfit: 0.0,
      totalExpenses: 0,
      totalNetProfit: 0.0,
      monthlyBreakdown: const [],
    );
  }
}
