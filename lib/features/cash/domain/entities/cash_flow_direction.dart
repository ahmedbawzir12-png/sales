/// اتجاه التدفق النقدي لحركة الصندوق
enum CashFlowDirection {
  /// تدفق مالي وارد (دخول / قبض في الصندوق)
  cashIn,

  /// تدفق مالي صادر (خروج / صرف من الصندوق)
  cashOut;

  String get arabicLabel {
    switch (this) {
      case CashFlowDirection.cashIn:
        return 'وارد (+)';
      case CashFlowDirection.cashOut:
        return 'صادر (-)';
    }
  }

  bool get isIncome => this == CashFlowDirection.cashIn;
  bool get isExpense => this == CashFlowDirection.cashOut;
}
