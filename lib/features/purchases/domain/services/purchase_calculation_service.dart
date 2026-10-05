import 'package:sales/core/domain/errors/exceptions.dart';

/// خدمة حسابات فاتورة الشراء والتحقق من القيود المالية
/// تضمن خلو الحسابات من أي أخطاء رياضية أو تجاوزات غير صالحة
class PurchaseCalculationService {
  PurchaseCalculationService._();

  /// حساب إجمالي السطر الواحد (الكمية × سعر التكلفة)
  static int calculateItemTotal(double quantity, int unitCost) {
    if (quantity < 0) {
      throw const ValidationException('كمية الصنف لا يمكن أن تكون سالبة');
    }
    if (unitCost < 0) {
      throw const ValidationException('تكلفة شراء الوحدة لا يمكن أن تكون سالبة');
    }
    return (quantity * unitCost).round();
  }

  /// حساب المجموع الفرعي لمجموعة أسطر
  static int calculateSubtotal(Iterable<int> itemTotals) {
    return itemTotals.fold(0, (sum, item) => sum + item);
  }

  /// حساب الصافي النهائي بعد خصم الفاتورة مع التحقق من عدم تجاوز الخصم
  static int calculateTotal(int subtotal, int discount) {
    if (discount < 0) {
      throw const ValidationException('قيمة الخصم لا يمكن أن تكون سالبة');
    }
    if (discount > subtotal) {
      throw const ValidationException('قيمة الخصم لا يمكن أن تتجاوز إجمالي الفاتورة');
    }
    return subtotal - discount;
  }

  /// حساب المبلغ المتبقي (الدين) بناءً على الإجمالي والمدفوع
  static int calculateRemaining(int total, int paidAmount) {
    if (paidAmount < 0) {
      throw const ValidationException('المبلغ المدفوع لا يمكن أن يكون سالباً');
    }
    if (paidAmount > total) {
      throw const ValidationException('المبلغ المدفوع لا يمكن أن يتجاوز صافي الفاتورة');
    }
    return total - paidAmount;
  }
}
