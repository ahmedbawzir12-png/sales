import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'database_migration.dart';

/// الهجرة السادسة: إنشاء جداول الصندوق وحركات النقدية (Cash Transactions) والمصروفات وتصنيفاتها
class MigrationV6 implements DatabaseMigration {
  @override
  int get version => 6;

  @override
  String get description =>
      'إنشاء جداول الصندوق وحركات النقدية (Cash Transactions) والمصروفات وتصنيفاتها وتغذية التصنيفات الافتراضية';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. جدول حركات الصندوق الموحد (Cash Transactions)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCashTransactions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        transaction_date TEXT NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        description TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cash_transactions_date 
      ON ${DatabaseConstants.tableCashTransactions} (transaction_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cash_transactions_type 
      ON ${DatabaseConstants.tableCashTransactions} (transaction_type);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cash_transactions_direction 
      ON ${DatabaseConstants.tableCashTransactions} (direction);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cash_transactions_ref 
      ON ${DatabaseConstants.tableCashTransactions} (reference_type, reference_id);
    ''');

    // 2. جدول تصنيفات المصروفات (Expense Categories)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableExpenseCategories} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    // بذر تصنيفات المصروفات الافتراضية
    final defaultCategories = [
      'كهرباء',
      'ماء',
      'إيجار',
      'نقل ومواصلات',
      'رواتب وأجور',
      'صيانة وإصلاحات',
      'إنترنت واتصالات',
      'مصروفات تشغيلية عامة',
      'ضيافة ونظافة',
    ];

    for (final catName in defaultCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableExpenseCategories} (name, is_active, created_at)
        VALUES (?, 1, ?);
      ''', [catName, now]);
    }

    // 3. جدول المصروفات (Expenses)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableExpenses} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        expense_date TEXT NOT NULL,
        description TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_date 
      ON ${DatabaseConstants.tableExpenses} (expense_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_category 
      ON ${DatabaseConstants.tableExpenses} (category_name);
    ''');

    // تسجيل تنفيذ الهجرة في جدول schema_migrations
    await db.execute('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES ($version, '$description', '$now');
    ''');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableExpenses};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableExpenseCategories};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableCashTransactions};');
    await db.execute(
      'DELETE FROM ${DatabaseConstants.tableMigrations} WHERE version = $version;',
    );
  }
}
