import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة الخامسة: إنشاء جداول دورة الديون (أستاذ العملاء والموردين، المدفوعات) والمرتجعات (مبيعات ومشتريات)
class MigrationV5 implements DatabaseMigration {
  @override
  int get version => 5;

  @override
  String get description =>
      'إنشاء جداول أستاذ العملاء والموردين والمدفوعات ومرتجعات المبيعات والمشتريات وتفاصيلها';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. جدول أستاذ العميل / حركات العميل المالية (Customer Ledger)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCustomerLedger} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${DatabaseConstants.tableCustomers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customer_ledger_cust_id 
      ON ${DatabaseConstants.tableCustomerLedger} (customer_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customer_ledger_date 
      ON ${DatabaseConstants.tableCustomerLedger} (transaction_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customer_ledger_type 
      ON ${DatabaseConstants.tableCustomerLedger} (transaction_type);
    ''');

    // 2. جدول مدفوعات العملاء (Customer Payments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCustomerPayments} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${DatabaseConstants.tableCustomers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customer_payments_cust_id 
      ON ${DatabaseConstants.tableCustomerPayments} (customer_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_customer_payments_date 
      ON ${DatabaseConstants.tableCustomerPayments} (payment_date);
    ''');

    // 3. جدول أستاذ المورد / حركات المورد المالية (Supplier Ledger)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSupplierLedger} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES ${DatabaseConstants.tableSuppliers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_supplier_ledger_supp_id 
      ON ${DatabaseConstants.tableSupplierLedger} (supplier_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_supplier_ledger_date 
      ON ${DatabaseConstants.tableSupplierLedger} (transaction_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_supplier_ledger_type 
      ON ${DatabaseConstants.tableSupplierLedger} (transaction_type);
    ''');

    // 4. جدول مدفوعات الموردين (Supplier Payments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSupplierPayments} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_number TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES ${DatabaseConstants.tableSuppliers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_supplier_payments_supp_id 
      ON ${DatabaseConstants.tableSupplierPayments} (supplier_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_supplier_payments_date 
      ON ${DatabaseConstants.tableSupplierPayments} (payment_date);
    ''');

    // 5. جدول مرتجعات المبيعات (Sales Returns)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSalesReturns} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT NOT NULL UNIQUE,
        sales_invoice_id INTEGER NOT NULL,
        customer_id INTEGER,
        return_date TEXT NOT NULL,
        total INTEGER NOT NULL,
        refund_amount INTEGER NOT NULL DEFAULT 0,
        debt_reduction_amount INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sales_invoice_id) REFERENCES ${DatabaseConstants.tableSalesInvoices} (id) ON DELETE RESTRICT,
        FOREIGN KEY (customer_id) REFERENCES ${DatabaseConstants.tableCustomers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_returns_invoice_id 
      ON ${DatabaseConstants.tableSalesReturns} (sales_invoice_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_returns_customer_id 
      ON ${DatabaseConstants.tableSalesReturns} (customer_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_returns_date 
      ON ${DatabaseConstants.tableSalesReturns} (return_date);
    ''');

    // 6. جدول بنود وتفاصيل مرتجع المبيعات (Sales Return Items)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSalesReturnItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sales_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL,
        unit_cost_at_sale REAL NOT NULL,
        total INTEGER NOT NULL,
        FOREIGN KEY (sales_return_id) REFERENCES ${DatabaseConstants.tableSalesReturns} (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_return_items_return_id 
      ON ${DatabaseConstants.tableSalesReturnItems} (sales_return_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_return_items_prod_id 
      ON ${DatabaseConstants.tableSalesReturnItems} (product_id);
    ''');

    // 7. جدول مرتجعات المشتريات (Purchase Returns)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePurchaseReturns} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT NOT NULL UNIQUE,
        purchase_invoice_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        return_date TEXT NOT NULL,
        total INTEGER NOT NULL,
        refund_amount INTEGER NOT NULL DEFAULT 0,
        debt_reduction_amount INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_invoice_id) REFERENCES ${DatabaseConstants.tablePurchaseInvoices} (id) ON DELETE RESTRICT,
        FOREIGN KEY (supplier_id) REFERENCES ${DatabaseConstants.tableSuppliers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_returns_invoice_id 
      ON ${DatabaseConstants.tablePurchaseReturns} (purchase_invoice_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_returns_supplier_id 
      ON ${DatabaseConstants.tablePurchaseReturns} (supplier_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_returns_date 
      ON ${DatabaseConstants.tablePurchaseReturns} (return_date);
    ''');

    // 8. جدول بنود وتفاصيل مرتجع المشتريات (Purchase Return Items)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePurchaseReturnItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost INTEGER NOT NULL,
        total INTEGER NOT NULL,
        FOREIGN KEY (purchase_return_id) REFERENCES ${DatabaseConstants.tablePurchaseReturns} (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_return_items_return_id 
      ON ${DatabaseConstants.tablePurchaseReturnItems} (purchase_return_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_return_items_prod_id 
      ON ${DatabaseConstants.tablePurchaseReturnItems} (product_id);
    ''');

    // 9. ترحيل ديون المبيعات الآجلة السابقة المكتملة إلى أستاذ العميل للحفاظ على الاتساق التاريخي
    await db.execute('''
      INSERT INTO ${DatabaseConstants.tableCustomerLedger} 
      (customer_id, transaction_type, amount, transaction_date, reference_type, reference_id, notes, created_at)
      SELECT 
        customer_id, 
        'sale_credit', 
        remaining_amount, 
        invoice_date, 
        'sales_invoice', 
        id, 
        'فاتورة مبيعات آجلة سابقة رقم ' || invoice_number, 
        created_at
      FROM ${DatabaseConstants.tableSalesInvoices}
      WHERE payment_type = 'credit' AND status = 'completed' AND customer_id IS NOT NULL AND remaining_amount > 0;
    ''');

    // 10. ترحيل ديون المشتريات الآجلة السابقة المكتملة إلى أستاذ المورد للحفاظ على الاتساق التاريخي
    await db.execute('''
      INSERT INTO ${DatabaseConstants.tableSupplierLedger} 
      (supplier_id, transaction_type, amount, transaction_date, reference_type, reference_id, notes, created_at)
      SELECT 
        supplier_id, 
        'purchase_credit', 
        remaining_amount, 
        invoice_date, 
        'purchase_invoice', 
        id, 
        'فاتورة مشتريات آجلة سابقة رقم ' || invoice_number, 
        created_at
      FROM ${DatabaseConstants.tablePurchaseInvoices}
      WHERE payment_type = 'credit' AND status = 'completed' AND remaining_amount > 0;
    ''');

    // 11. توثيق الهجرة
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tablePurchaseReturnItems};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tablePurchaseReturns};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSalesReturnItems};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSalesReturns};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSupplierPayments};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSupplierLedger};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableCustomerPayments};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableCustomerLedger};');
  }
}
