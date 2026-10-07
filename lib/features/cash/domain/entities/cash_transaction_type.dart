import 'cash_flow_direction.dart';

/// أنواع حركات الصندوق المالي
enum CashTransactionType {
  /// رصيد افتتاحي للصندوق
  openingBalance,

  /// مبيعات نقدية
  sale,

  /// سداد دفعة من عميل
  customerPayment,

  /// مشتريات نقدية
  purchase,

  /// سداد دفعة لمورد
  supplierPayment,

  /// استرداد نقدي لمرتجع مبيعات
  salesReturnRefund,

  /// استرداد نقدي من مرتجع مشتريات
  purchaseReturnRefund,

  /// مصروف تشغيلي
  expense,

  /// مسحوبات المالك الشخصية
  ownerWithdrawal,

  /// إيراد نقدي آخر
  otherIncome,

  /// إيداع نقدي آخر / تمويل الصندوق
  otherDeposit,

  /// تسوية فروقات الصندوق
  adjustment;

  /// الوصف العربي لنوع الحركة
  String get arabicLabel {
    switch (this) {
      case CashTransactionType.openingBalance:
        return 'رصيد افتتاحي';
      case CashTransactionType.sale:
        return 'مبيعات نقدية';
      case CashTransactionType.customerPayment:
        return 'دفعة من عميل';
      case CashTransactionType.purchase:
        return 'مشتريات نقدية';
      case CashTransactionType.supplierPayment:
        return 'دفعة لمورد';
      case CashTransactionType.salesReturnRefund:
        return 'استرداد مرتجع مبيعات';
      case CashTransactionType.purchaseReturnRefund:
        return 'استرداد مرتجع مشتريات';
      case CashTransactionType.expense:
        return 'مصروف تشغيلي';
      case CashTransactionType.ownerWithdrawal:
        return 'مسحوبات المالك';
      case CashTransactionType.otherIncome:
        return 'إيراد نقدي آخر';
      case CashTransactionType.otherDeposit:
        return 'إيداع نقدي إضافي';
      case CashTransactionType.adjustment:
        return 'تسوية صندوق';
    }
  }

  /// الاتجاه الطبيعي للحركة (وارد أو صادر)
  CashFlowDirection get defaultDirection {
    switch (this) {
      case CashTransactionType.openingBalance:
      case CashTransactionType.sale:
      case CashTransactionType.customerPayment:
      case CashTransactionType.purchaseReturnRefund:
      case CashTransactionType.otherIncome:
      case CashTransactionType.otherDeposit:
        return CashFlowDirection.cashIn;
      case CashTransactionType.purchase:
      case CashTransactionType.supplierPayment:
      case CashTransactionType.salesReturnRefund:
      case CashTransactionType.expense:
      case CashTransactionType.ownerWithdrawal:
        return CashFlowDirection.cashOut;
      case CashTransactionType.adjustment:
        return CashFlowDirection.cashIn;
    }
  }
}
