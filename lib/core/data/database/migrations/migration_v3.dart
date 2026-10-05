import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة الثالثة: إضافة تكلفة المخزون للمنتجات وجداول الموردين وفواتير الشراء وتفاصيلها
class MigrationV3 implements DatabaseMigration {
  @override
  int get version => 3;

  @override
  String get description =>
      'إضافة عمود متوسط التكلفة المرجح للمنتجات وإنشاء جداول الموردين وفواتير وتفاصيل المشتريات';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. إضافة عمود average_cost لجدول المنتجات لحساب المتوسط المرجح لتكلفة المخزون
    // نتحقق أولاً إن كان العمود غير موجود لتفادي الأخطاء في حال إعادة التشغيل
    final productInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableProducts});');
    final hasAverageCost = productInfo.any((col) => col['name'] == 'average_cost');
    if (!hasAverageCost) {
      await db.execute('''
        ALTER TABLE ${DatabaseConstants.tableProducts} 
        ADD COLUMN average_cost REAL NOT NULL DEFAULT 0.0;
      ''');

      // تعيين التكلفة الأولية مساوية لسعر الشراء المسجل مسبقاً
      await db.execute('''
        UPDATE ${DatabaseConstants.tableProducts}
        SET average_cost = CAST(purchase_price AS REAL)
        WHERE average_cost = 0.0;
      ''');
    }

    // 2. جدول الموردين
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSuppliers} (
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
      CREATE INDEX IF NOT EXISTS idx_suppliers_is_active 
      ON ${DatabaseConstants.tableSuppliers} (is_active);
    ''');

    // 3. جدول فواتير الشراء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePurchaseInvoices} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL,
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
        FOREIGN KEY (supplier_id) REFERENCES ${DatabaseConstants.tableSuppliers} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_id 
      ON ${DatabaseConstants.tablePurchaseInvoices} (supplier_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_invoices_invoice_date 
      ON ${DatabaseConstants.tablePurchaseInvoices} (invoice_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_invoices_status 
      ON ${DatabaseConstants.tablePurchaseInvoices} (status);
    ''');

    // 4. جدول تفاصيل وبنود فاتورة الشراء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePurchaseInvoiceItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost INTEGER NOT NULL,
        total INTEGER NOT NULL,
        FOREIGN KEY (purchase_invoice_id) REFERENCES ${DatabaseConstants.tablePurchaseInvoices} (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice_id 
      ON ${DatabaseConstants.tablePurchaseInvoiceItems} (purchase_invoice_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_purchase_items_product_id 
      ON ${DatabaseConstants.tablePurchaseInvoiceItems} (product_id);
    ''');

    // 5. بذر موردين افتراضيين لتسهيل التجربة
    final defaultSuppliers = [
      {
        'name': 'شركة الأندلس للأقمشة والمفروشات',
        'phone': '771234567',
        'whatsapp': '771234567',
        'address': 'صنعاء - شارع تعز',
        'notes': 'مورد رئيسي للأقمشة والستائر',
      },
      {
        'name': 'مصنع الجزيرة للإسفنج والمراتب',
        'phone': '777890123',
        'whatsapp': '777890123',
        'address': 'صنعاء - شارع الستين',
        'notes': 'توريد مراتب طبية وإسفنج ضغط عالي',
      },
      {
        'name': 'مؤسسة النجاح للمفروشات الخشبية',
        'phone': '770987654',
        'whatsapp': '770987654',
        'address': 'عدن - المنصورة',
        'notes': 'أطقم غرف نوم ومجالس خشبية',
      },
    ];

    for (final s in defaultSuppliers) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableSuppliers} 
        (name, phone, whatsapp, address, notes, current_balance, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 0, 1, ?, ?)
      ''', [s['name'], s['phone'], s['whatsapp'], s['address'], s['notes'], now, now]);
    }

    // 6. توثيق الهجرة في جدول سجل الهجرات
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tablePurchaseInvoiceItems};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tablePurchaseInvoices};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSuppliers};');
  }
}
