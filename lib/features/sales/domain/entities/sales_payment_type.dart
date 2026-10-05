/// نوع سداد فاتورة المبيعات
enum SalesPaymentType {
  cash,
  credit;

  String get arabicLabel {
    switch (this) {
      case SalesPaymentType.cash:
        return 'نقدي';
      case SalesPaymentType.credit:
        return 'آجل';
    }
  }

  static SalesPaymentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'credit':
        return SalesPaymentType.credit;
      case 'cash':
      default:
        return SalesPaymentType.cash;
    }
  }
}
