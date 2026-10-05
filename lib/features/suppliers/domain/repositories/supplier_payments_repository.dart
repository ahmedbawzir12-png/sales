import '../entities/supplier_payment.dart';

abstract class SupplierPaymentsRepository {
  /// توليد رقم تسلسلي فريد لدفعة المورد (SPAY-YYYYMMDD-XXXX)
  Future<String> generateNextPaymentNumber();

  /// استرجاع دفعات الموردين مع إمكانية التصفية بحسب المورد
  Future<List<SupplierPayment>> getPayments({int? supplierId});

  /// تسجيل دفعة جديدة للمورد كعملية ذرية (Atomic Transaction)
  /// تفحص عدم تجاوز الدين وتسجل حركة في أستاذ المورد وتجهز التدفق المالي للصندوق
  Future<SupplierPayment> recordPayment(SupplierPayment payment);
}
