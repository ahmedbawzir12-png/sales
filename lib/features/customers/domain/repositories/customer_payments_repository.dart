import '../entities/customer_payment.dart';

abstract class CustomerPaymentsRepository {
  /// توليد رقم تسلسلي فريد لدفعة العميل (CPAY-YYYYMMDD-XXXX)
  Future<String> generateNextPaymentNumber();

  /// استرجاع دفعات العملاء مع إمكانية التصفية بحسب العميل
  Future<List<CustomerPayment>> getPayments({int? customerId});

  /// تسجيل دفعة جديدة للعميل كعملية ذرية (Atomic Transaction)
  /// تفحص عدم تجاوز الدين وتسجل حركة في أستاذ العميل وتجهز التدفق المالي للصندوق
  Future<CustomerPayment> recordPayment(CustomerPayment payment);
}
