import 'package:flutter/foundation.dart';

/// نوع التدفق المالي (دخول أو خروج من الصندوق)
enum FinancialFlowType {
  /// تدفق مالي وارد (قبض / دخول إلى الصندوق)
  cashIn,

  /// تدفق مالي صادر (صرف / خروج من الصندوق)
  cashOut;

  String get arabicLabel {
    switch (this) {
      case FinancialFlowType.cashIn:
        return 'قبض نقدي وارد';
      case FinancialFlowType.cashOut:
        return 'صرف نقدي صادر';
    }
  }
}

/// مصدر التدفق المالي
enum FinancialFlowSource {
  /// مبيعات نقدية
  cashSale,

  /// دفعة مسددة من عميل
  customerPayment,

  /// دفعة مسددة لمورد
  supplierPayment,

  /// مبلغ مسترد للعميل عن مرتجع مبيعات
  salesReturnRefund,

  /// مبلغ مسترد من مورد عن مرتجع مشتريات
  purchaseReturnRefund;

  String get arabicLabel {
    switch (this) {
      case FinancialFlowSource.cashSale:
        return 'مبيعات نقدية';
      case FinancialFlowSource.customerPayment:
        return 'دفعة من عميل';
      case FinancialFlowSource.supplierPayment:
        return 'دفعة لمورد';
      case FinancialFlowSource.salesReturnRefund:
        return 'استرداد نقدي لمرتجع مبيعات';
      case FinancialFlowSource.purchaseReturnRefund:
        return 'استرداد نقدي من مرتجع مشتريات';
    }
  }
}

/// سجل حركة التدفق المالي المعد للربط المباشر مع صندوق النقدية في المرحلة السادسة
class FinancialFlowRecord {
  final FinancialFlowType type;
  final FinancialFlowSource source;
  final int amount;
  final String referenceType;
  final int referenceId;
  final String description;
  final DateTime date;

  const FinancialFlowRecord({
    required this.type,
    required this.source,
    required this.amount,
    required this.referenceType,
    required this.referenceId,
    required this.description,
    required this.date,
  });

  @override
  String toString() =>
      'FinancialFlowRecord(${type.name}, ${source.name}, $amount, ref: $referenceType#$referenceId)';
}

/// خدمة نقطة التكامل المالي لربط الصندوق في المرحلة السادسة
class FinancialFlowIntegrationService {
  FinancialFlowIntegrationService._();
  static final FinancialFlowIntegrationService instance = FinancialFlowIntegrationService._();

  final List<void Function(FinancialFlowRecord)> _listeners = [];
  final List<FinancialFlowRecord> _recentFlows = [];

  List<FinancialFlowRecord> get recentFlows => List.unmodifiable(_recentFlows);

  void addListener(void Function(FinancialFlowRecord) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(FinancialFlowRecord) listener) {
    _listeners.remove(listener);
  }

  /// إشعار وتجهيز التدفق المالي
  void dispatchFlow(FinancialFlowRecord record) {
    _recentFlows.add(record);
    if (_recentFlows.length > 100) {
      _recentFlows.removeAt(0);
    }
    for (final listener in _listeners) {
      try {
        listener(record);
      } catch (e) {
        debugPrint('Error in FinancialFlow listener: $e');
      }
    }
  }

  /// تنظيف السجلات للاختبارات
  void clearForTesting() {
    _recentFlows.clear();
    _listeners.clear();
  }
}
