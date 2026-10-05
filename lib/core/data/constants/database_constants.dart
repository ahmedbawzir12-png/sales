/// ثوابت قاعدة البيانات المحلية SQLite التابعة لطبقة البيانات
class DatabaseConstants {
  DatabaseConstants._();

  /// اسم ملف قاعدة البيانات
  static const String databaseName = 'furniture_sales.db';

  /// الإصدار الحالي لقاعدة البيانات (المرحلة الرابعة: العملاء والمبيعات)
  static const int databaseVersion = 4;

  /// أوامر التهيئة (Pragmas)
  static const String pragmaForeignKeysOn = 'PRAGMA foreign_keys = ON;';

  /// أسماء الجداول
  static const String tableMigrations = 'schema_migrations';
  static const String tableStoreProfile = 'store_profile';
  static const String tableCategories = 'categories';
  static const String tableUnits = 'units';
  static const String tableProducts = 'products';
  static const String tableStockMovements = 'stock_movements';
  static const String tableSuppliers = 'suppliers';
  static const String tablePurchaseInvoices = 'purchase_invoices';
  static const String tablePurchaseInvoiceItems = 'purchase_invoice_items';
  static const String tableCustomers = 'customers';
  static const String tableSalesInvoices = 'sales_invoices';
  static const String tableSalesInvoiceItems = 'sales_invoice_items';
}
