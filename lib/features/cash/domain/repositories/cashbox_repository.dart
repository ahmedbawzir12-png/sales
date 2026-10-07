import '../entities/cash_flow_direction.dart';
import '../entities/cash_transaction.dart';
import '../entities/cash_transaction_type.dart';
import '../entities/cashbox_summary.dart';

/// واجهة مستودع الصندوق النقدي
abstract class CashboxRepository {
  /// استرجاع الرصيد الحالي الفعلي للصندوق (محسوب من كامل الحركات)
  Future<int> getCashBalance();

  /// استرجاع ملخص وأرقام الصندوق (رصيد اليوم، الداخل، الخارج، الصافي)
  Future<CashboxSummary> getCashboxSummary({DateTime? from, DateTime? to});

  /// استرجاع قائمة حركات الصندوق مع الفلترة الاختيارية
  Future<List<CashTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    CashFlowDirection? direction,
    CashTransactionType? type,
  });

  /// التحقق هل تم إدخال رصيد افتتاحي للصندوق مسبقاً
  Future<bool> hasOpeningBalance();

  /// استرجاع حركة الرصيد الافتتاحي إن وجدت
  Future<CashTransaction?> getOpeningBalance();

  /// تسجيل الرصيد الافتتاحي لأول مرة (يمنع التكرار)
  Future<CashTransaction> setOpeningBalance(
    int amount, {
    DateTime? date,
    String? notes,
  });

  /// تسجيل حركة صندوق نقدية جديدة مع التحقق الصارم من عدم جعل الرصيد سالباً ومنع التكرار
  Future<CashTransaction> recordCashTransaction(CashTransaction transaction);

  /// تسجيل حركة صندوق عبر منفذ معاملات محدد لدعم الـ Atomic SQLite Transactions
  Future<CashTransaction> recordCashTransactionWithExecutor(
    dynamic executor,
    CashTransaction transaction,
  );

  /// تسجيل سحب نقدية شخصي لصاحب المحل
  Future<CashTransaction> recordOwnerWithdrawal(
    int amount, {
    DateTime? date,
    String? notes,
  });

  /// تسجيل إيداع نقدية إضافي في الصندوق (تمويل رأس مال / دخل آخر)
  Future<CashTransaction> recordOtherDeposit(
    int amount, {
    DateTime? date,
    String? description,
    String? notes,
  });
}
