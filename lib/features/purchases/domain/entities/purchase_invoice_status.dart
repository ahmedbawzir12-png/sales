/// حالة فاتورة الشراء
enum PurchaseInvoiceStatus {
  completed,
  cancelled;

  String get arabicLabel {
    switch (this) {
      case PurchaseInvoiceStatus.completed:
        return 'مكتملة';
      case PurchaseInvoiceStatus.cancelled:
        return 'ملغاة';
    }
  }

  static PurchaseInvoiceStatus fromString(String value) {
    return PurchaseInvoiceStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PurchaseInvoiceStatus.completed,
    );
  }
}
