import '../../../../core/domain/errors/exceptions.dart';
import '../entities/sales_invoice_item.dart';
import '../entities/sales_payment_type.dart';

/// خدمة الحسابات المالية والتحقق لفواتير المبيعات
class SalesCalculationService {
  const SalesCalculationService();

  /// حساب إجمالي السطر (الكمية × السعر) - الخصم
  int calculateItemTotal({
    required double quantity,
    required int unitPrice,
    int discount = 0,
  }) {
    if (quantity <= 0) {
      throw const ValidationException('كمية الصنف في المبيعات يجب أن تكون أكبر من الصفر');
    }
    if (unitPrice < 0) {
      throw const ValidationException('سعر البيع لا يمكن أن يكون سالباً');
    }
    if (discount < 0) {
      throw const ValidationException('خصم السطر لا يمكن أن يكون سالباً');
    }

    final raw = (quantity * unitPrice).round();
    if (discount > raw) {
      throw const ValidationException('خصم السطر لا يمكن أن يتجاوز إجمالي الصنف');
    }

    return raw - discount;
  }

  /// حساب إجمالي تكلفة البضاعة المباعة للسطر وقت البيع
  double calculateItemCostTotal({
    required double quantity,
    required double unitCostAtSale,
  }) {
    if (quantity <= 0) return 0.0;
    if (unitCostAtSale < 0) return 0.0;
    return quantity * unitCostAtSale;
  }

  /// حساب المجموع الفرعي للفاتورة (مجموع بنود الفاتورة)
  int calculateSubtotal(List<SalesInvoiceItem> items) {
    if (items.isEmpty) return 0;
    return items.fold<int>(0, (sum, item) => sum + item.total);
  }

  /// حساب إجمالي التكلفة التاريخية لجميع بنود الفاتورة
  double calculateTotalCost(List<SalesInvoiceItem> items) {
    if (items.isEmpty) return 0.0;
    return items.fold<double>(0.0, (sum, item) => sum + item.costTotal);
  }

  /// حساب الصافي النهائي بعد خصم الفاتورة العام
  int calculateTotalAmount({
    required int subtotal,
    int discount = 0,
  }) {
    if (subtotal < 0) {
      throw const ValidationException('المجموع الفرعي لا يمكن أن يكون سالباً');
    }
    if (discount < 0) {
      throw const ValidationException('مبلغ الخصم لا يمكن أن يكون سالباً');
    }
    if (discount > subtotal) {
      throw const ValidationException('مبلغ الخصم لا يمكن أن يتجاوز المجموع الفرعي للفاتورة');
    }

    return subtotal - discount;
  }

  /// حساب المبلغ المتبقي (دين العميل) بدقة
  int calculateRemainingAmount({
    required int totalAmount,
    required int paidAmount,
    required SalesPaymentType paymentType,
  }) {
    if (paidAmount < 0) {
      throw const ValidationException('المبلغ المدفوع لا يمكن أن يكون سالباً');
    }
    if (paidAmount > totalAmount) {
      throw const ValidationException('المبلغ المدفوع لا يمكن أن يتجاوز إجمالي الفاتورة');
    }

    if (paymentType == SalesPaymentType.cash) {
      return 0;
    }

    return totalAmount - paidAmount;
  }
}
