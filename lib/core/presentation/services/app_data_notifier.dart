import 'package:flutter/foundation.dart';

/// أنواع الأحداث وتغييرات البيانات في النظام
enum AppDataChangeType {
  inventory,
  sales,
  purchases,
  customers,
  suppliers,
  cashbox,
  expenses,
  tabSelection,
  all,
}

/// كائن حدث تغيير البيانات الحية
class AppDataChangeEvent {
  final AppDataChangeType type;
  final dynamic payload;

  const AppDataChangeEvent({required this.type, this.payload});
}

/// خدمة إشعار وتزامن البيانات اللحظية عبر كامل شاشات وأقسام النظام (Reactive Event Dispatcher)
/// تضمن تحديث شاشات المنتجات، الجرد، المبيعات، المشتريات، العملاء والموردين فور وقوع أي حركة محاسبية أو مخزنية
class AppDataNotifier extends ChangeNotifier {
  static final AppDataNotifier instance = AppDataNotifier._();
  AppDataNotifier._();

  AppDataChangeEvent? _lastEvent;
  AppDataChangeEvent? get lastEvent => _lastEvent;

  /// إشعار بتغير المخزون (بيع، شراء، مردود مبيعات/مشتريات، تسوية جرد، تعديل منتج)
  void notifyInventoryChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.inventory, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير فواتير وحركات المبيعات
  void notifySalesChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.sales, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير فواتير وحركات المشتريات
  void notifyPurchasesChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.purchases, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير بيانات العملاء، ديونهم، وسندات القبض
  void notifyCustomersChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.customers, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير بيانات الموردين، ديونهم، وسندات الصرف
  void notifySuppliersChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.suppliers, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير حركات ورصيد الصندوق (Cashbox)
  void notifyCashboxChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.cashbox, payload: payload);
    notifyListeners();
  }

  /// إشعار بتغير المصروفات وتصنيفاتها
  void notifyExpensesChanged([dynamic payload]) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.expenses, payload: payload);
    notifyListeners();
  }

  /// إشعار باختيار/التبديل إلى تبويب رئيسي معين في شريط التنقل
  void notifyTabSelected(int tabIndex) {
    _lastEvent = AppDataChangeEvent(type: AppDataChangeType.tabSelection, payload: tabIndex);
    notifyListeners();
  }

  /// إشعار شامل بتحديث كامل البيانات
  void notifyAll() {
    _lastEvent = const AppDataChangeEvent(type: AppDataChangeType.all);
    notifyListeners();
  }
}
