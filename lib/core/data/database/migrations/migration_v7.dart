import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة السابعة: إضافة فهارس مركبة لتحسين أداء استعلامات لوحة التحكم والتقارير المالية والمخزنية
class MigrationV7 implements DatabaseMigration {
  @override
  int get version => 7;

  @override
  String get description =>
      'إضافة فهارس مركبة لتحسين أداء استعلامات لوحة التحكم والتقارير المالية والمخزنية';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. فهارس المبيعات لتسريع تقارير المبيعات والأرباح حسب التاريخ والحالة
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_invoices_date_status 
      ON ${DatabaseConstants.tableSalesInvoices} (invoice_date, status);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_returns_date_status 
      ON ${DatabaseConstants.tableSalesReturns} (return_date, status);
    ''');

    // 2. فهارس المشتريات لتسريع تقارير المشتريات والموردين
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date_status 
      ON ${DatabaseConstants.tablePurchaseInvoices} (invoice_date, status);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_returns_date_status 
      ON ${DatabaseConstants.tablePurchaseReturns} (return_date, status);
    ''');

    // 3. فهارس المصروفات لتسريع فلترة وتجميع المصروفات حسب التاريخ والتصنيف
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_date_category 
      ON ${DatabaseConstants.tableExpenses} (expense_date, category_name);
    ''');

    // 4. توثيق الهجرة في جدول سجل الهجرات
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_sales_invoices_date_status;');
    await db.execute('DROP INDEX IF EXISTS idx_sales_returns_date_status;');
    await db.execute('DROP INDEX IF EXISTS idx_purchase_invoices_date_status;');
    await db.execute('DROP INDEX IF EXISTS idx_purchase_returns_date_status;');
    await db.execute('DROP INDEX IF EXISTS idx_expenses_date_category;');
    await db.execute(
      'DELETE FROM ${DatabaseConstants.tableMigrations} WHERE version = $version;',
    );
  }
}
