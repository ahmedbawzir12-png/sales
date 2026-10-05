/// حالة فاتورة المبيعات
enum SalesInvoiceStatus {
  completed,
  cancelled;

  String get arabicLabel {
    switch (this) {
      case SalesInvoiceStatus.completed:
        return 'مكتملة';
      case SalesInvoiceStatus.cancelled:
        return 'ملغاة';
    }
  }

  static SalesInvoiceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'cancelled':
        return SalesInvoiceStatus.cancelled;
      case 'completed':
      default:
        return SalesInvoiceStatus.completed;
    }
  }
}
