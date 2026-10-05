import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة الرابعة: إنشاء جداول العملاء وفواتير المبيعات وتفاصيلها لحساب تكلفة البيع والمخزون
class MigrationV4 implements DatabaseMigration {
  @override
  int get version => 4;

  @override
  String get description =>
      'إنشاء جداول العملاء وفواتير وتفاصيل المبيعات وسجل تكلفة البضاعة المباعة وقت البيع';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. جدول العملاء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCustomers} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        phone TEXT,
        whatsapp TEXT,
        address TEXT,
        notes TEXT,
        current_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customers_is_active 
      ON ${DatabaseConstants.tableCustomers} (is_active);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customers_name 
      ON ${DatabaseConstants.tableCustomers} (name);
    ''');

    // 2. جدول فواتير المبيعات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSalesInvoices} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        invoice_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        remaining_amount INTEGER NOT NULL DEFAULT 0,
        payment_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${DatabaseConstants.tableCustomers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_id 
      ON ${DatabaseConstants.tableSalesInvoices} (customer_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_invoices_invoice_date 
      ON ${DatabaseConstants.tableSalesInvoices} (invoice_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_invoices_status 
      ON ${DatabaseConstants.tableSalesInvoices} (status);
    ''');

    // 3. جدول تفاصيل وبنود فاتورة المبيعات (مع حفظ متوسط التكلفة وقت البيع unit_cost_at_sale)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSalesInvoiceItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sales_invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL,
        unit_cost_at_sale REAL NOT NULL,
        discount INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL,
        cost_total REAL NOT NULL,
        FOREIGN KEY (sales_invoice_id) REFERENCES ${DatabaseConstants.tableSalesInvoices} (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_items_invoice_id 
      ON ${DatabaseConstants.tableSalesInvoiceItems} (sales_invoice_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_items_product_id 
      ON ${DatabaseConstants.tableSalesInvoiceItems} (product_id);
    ''');

    // 4. بذر عميل نقدي افتراضي وعملاء تجريبيين
    final defaultCustomers = [
      {
        'name': 'عميل نقدي (زبون عام)',
        'phone': null,
        'whatsapp': null,
        'address': null,
        'notes': 'حساب نقدي عام للزبائن العاديين',
      },
      {
        'name': 'محمد عبدالله الصالح',
        'phone': '772233445',
        'whatsapp': '772233445',
        'address': 'صنعاء - حدة',
        'notes': 'عميل دائم لمفروشات غرف النوم',
      },
      {
        'name': 'فندق برج العرب السكني',
        'phone': '775566778',
        'whatsapp': '775566778',
        'address': 'عدن - المعلا',
        'notes': 'تجهيز أجنحة فندقية ومفارش',
      },
    ];

    for (final c in defaultCustomers) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableCustomers} 
        (name, phone, whatsapp, address, notes, current_balance, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 0, 1, ?, ?)
      ''', [c['name'], c['phone'], c['whatsapp'], c['address'], c['notes'], now, now]);
    }

    // 5. توثيق الهجرة
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSalesInvoiceItems};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSalesInvoices};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableCustomers};');
  }
}
