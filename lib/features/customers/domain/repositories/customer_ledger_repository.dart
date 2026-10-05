import '../entities/customer_ledger_entry.dart';

abstract class CustomerLedgerRepository {
  /// استرجاع سجل الحركات المالية للعميل
  Future<List<CustomerLedgerEntry>> getLedgerEntries(int customerId);

  /// حساب الرصيد المستحق الفعلي للعميل بناءً على عملياته المسجلة
  Future<int> getCustomerBalance(int customerId);

  /// تسجيل حركة في أستاذ العميل
  Future<int> recordEntry(CustomerLedgerEntry entry);
}
