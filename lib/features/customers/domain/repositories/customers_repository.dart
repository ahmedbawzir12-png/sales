import '../entities/customer.dart';

/// واجهة مستودع العملاء في طبقة النطاق
abstract class CustomersRepository {
  /// استرجاع قائمة العملاء مع خيارات الفلترة بالنشاط والبحث بالاسم أو الهاتف
  Future<List<Customer>> getCustomers({bool? onlyActive, String? searchQuery});

  /// استرجاع عميل معين بالمعرف
  Future<Customer> getCustomerById(int id);

  /// إضافة عميل جديد
  Future<int> createCustomer(Customer customer);

  /// تعديل بيانات عميل قائم
  Future<void> updateCustomer(Customer customer);

  /// تغيير حالة تنشيط/تعطيل العميل
  Future<void> toggleCustomerActive(int id, bool isActive);

  /// احتساب رصيد الدين الحالي للعميل تجميعياً من فواتير المبيعات الآجلة
  Future<int> getCustomerDebt(int customerId);

  /// استرجاع إحصائيات مبيعات العميل (عدد الفواتير، إجمالي المبيعات، إجمالي المدفوع، المتبقي)
  Future<Map<String, dynamic>> getCustomerStatistics(int customerId);
}
