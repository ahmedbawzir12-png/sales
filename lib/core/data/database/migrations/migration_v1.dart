import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import '../../../presentation/constants/app_constants.dart';
import 'database_migration.dart';

/// الهجرة الأولى: إنشاء جدول سجل الهجرات وجدول معلومات المتجر التأسيسي
class MigrationV1 implements DatabaseMigration {
  @override
  int get version => 1;

  @override
  String get description => 'إنشاء جدول تتبع الهجرات وجدول بيانات المتجر الأساسية';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. جدول تتبع الهجرات المنفذة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableMigrations} (
        version INTEGER PRIMARY KEY,
        description TEXT NOT NULL,
        applied_at TEXT NOT NULL
      );
    ''');

    // 2. جدول بيانات المتجر (صف مفرد id = 1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStoreProfile} (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        currency TEXT NOT NULL DEFAULT '${AppConstants.defaultCurrency}',
        updated_at TEXT NOT NULL
      );
    ''');

    // إدراج سجل افتراضي للمتجر عند أول إنشاء
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT OR IGNORE INTO ${DatabaseConstants.tableStoreProfile} (id, name, phone, address, currency, updated_at)
      VALUES (1, 'معرض المفروشات العصري', '', '', '${AppConstants.defaultCurrency}', ?)
    ''', [now]);

    // تسجيل الهجرة الحالية في جدول الهجرات
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseConstants.tableMigrations} (version, description, applied_at)
      VALUES (?, ?, ?)
    ''', [version, description, now]);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableStoreProfile};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableMigrations};');
  }
}
