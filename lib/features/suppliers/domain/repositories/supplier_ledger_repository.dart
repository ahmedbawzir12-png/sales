import '../entities/supplier_ledger_entry.dart';

abstract class SupplierLedgerRepository {
  /// استرجاع سجل الحركات المالية للمورد
  Future<List<SupplierLedgerEntry>> getLedgerEntries(int supplierId);

  /// حساب الرصيد المستحق الفعلي للمورد بناءً على عملياته المسجلة
  Future<int> getSupplierBalance(int supplierId);

  /// تسجيل حركة في أستاذ المورد
  Future<int> recordEntry(SupplierLedgerEntry entry);
}
