import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة الثانية: إنشاء جداول التصنيفات، وحدات القياس، المنتجات، وحركات المخزون
class MigrationV2 implements DatabaseMigration {
  @override
  int get version => 2;

  @override
  String get description =>
      'إنشاء جداول التصنيفات والوحدات والمنتجات وسجل حركات المخزون مع بياناتها الأولية';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. جدول التصنيفات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCategories} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. جدول وحدات القياس
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUnits} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        symbol TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    // 3. جدول المنتجات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableProducts} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        unit_id INTEGER NOT NULL,
        purchase_price INTEGER NOT NULL,
        sale_price INTEGER NOT NULL,
        current_stock REAL NOT NULL DEFAULT 0.0,
        minimum_stock REAL NOT NULL DEFAULT 0.0,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES ${DatabaseConstants.tableCategories} (id) ON DELETE RESTRICT,
        FOREIGN KEY (unit_id) REFERENCES ${DatabaseConstants.tableUnits} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_category_id 
      ON ${DatabaseConstants.tableProducts} (category_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_is_active 
      ON ${DatabaseConstants.tableProducts} (is_active);
    ''');

    // 4. جدول سجل حركة المخزون
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStockMovements} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        stock_before REAL NOT NULL,
        stock_after REAL NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        reference TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts} (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id 
      ON ${DatabaseConstants.tableStockMovements} (product_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at 
      ON ${DatabaseConstants.tableStockMovements} (created_at);
    ''');

    // 5. بذر التصنيفات الأولية لمعرض المفروشات
    final defaultCategories = [
      'فرش أرضيات وسجاد',
      'أطقم كنب ومجالس',
      'فرش نوم ومفارش',
      'ستائر وديكورات',
      'مخدات ولحف',
    ];

    for (final catName in defaultCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableCategories} (name, description, is_active, created_at, updated_at)
        VALUES (?, '', 1, ?, ?)
      ''', [catName, now, now]);
    }

    // 6. بذر وحدات القياس الشائعة
    final defaultUnits = [
      {'name': 'قطعة', 'symbol': 'قطعة'},
      {'name': 'متر', 'symbol': 'م'},
      {'name': 'طقم', 'symbol': 'طقم'},
      {'name': 'رول', 'symbol': 'رول'},
      {'name': 'كرتون', 'symbol': 'كرتون'},
    ];

    for (final unit in defaultUnits) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableUnits} (name, symbol, created_at)
        VALUES (?, ?, ?)
      ''', [unit['name'], unit['symbol'], now]);
    }

    // 7. توثيق الهجرة في جدول سجل الهجرات
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableStockMovements};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableProducts};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableUnits};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableCategories};');
  }
}
