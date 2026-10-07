import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../domain/errors/exceptions.dart';
import '../constants/database_constants.dart';
import 'migrations/database_migration.dart';
import 'migrations/migration_v1.dart';
import 'migrations/migration_v2.dart';
import 'migrations/migration_v3.dart';
import 'migrations/migration_v4.dart';
import 'migrations/migration_v5.dart';
import 'migrations/migration_v6.dart';
import 'migrations/migration_v7.dart';

/// خدمة إدارة دورة حياة قاعدة البيانات المحلية SQLite التابعة لطبقة البيانات
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  Database? _database;
  Completer<Database>? _initCompleter;

  /// قائمة ملفات الترحيل المرتبة حسب الإصدار
  List<DatabaseMigration> get _migrations => [
        MigrationV1(),
        MigrationV2(),
        MigrationV3(),
        MigrationV4(),
        MigrationV5(),
        MigrationV6(),
        MigrationV7(),
      ];

  /// الحصول على الاتصال الفعال بقاعدة البيانات
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _database = db;
      _initCompleter!.complete(db);
      return db;
    } catch (e, stackTrace) {
      _initCompleter!.completeError(
        DatabaseException('فشل فتح قاعدة البيانات المحلية', e),
        stackTrace,
      );
      _initCompleter = null;
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  /// فتح وتهيئة قاعدة البيانات
  Future<Database> _initDatabase({String? customPath, bool inMemory = false}) async {
    final String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else if (customPath != null) {
      path = customPath;
    } else {
      final databasesPath = await getDatabasesPath();
      path = p.join(databasesPath, DatabaseConstants.databaseName);
    }

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// تهيئة إعدادات الجلسة وتفعيل القيود المرجعية للمفاتيح الأجنبية
  Future<void> _onConfigure(Database db) async {
    await db.execute(DatabaseConstants.pragmaForeignKeysOn);
  }

  /// إنشاء قاعدة البيانات لأول مرة بتطبيق جميع الهجرات المسجلة داخل Transaction
  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      for (final migration in _migrations) {
        if (migration.version <= version) {
          await migration.up(txn);
        }
      }
    });
  }

  /// ترقية قاعدة البيانات بتطبيق الهجرات اللاحقة بالتسلسل داخل Transaction
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      final pendingMigrations = _migrations
          .where((m) => m.version > oldVersion && m.version <= newVersion)
          .toList()
        ..sort((a, b) => a.version.compareTo(b.version));

      for (final migration in pendingMigrations) {
        await migration.up(txn);
      }
    });
  }

  /// الرجوع لإصدار سابق إن حدث ذلك
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      final revertMigrations = _migrations
          .where((m) => m.version <= oldVersion && m.version > newVersion)
          .toList()
        ..sort((a, b) => b.version.compareTo(a.version));

      for (final migration in revertMigrations) {
        await migration.down(txn);
      }
    });
  }

  /// تهيئة مخصصة للاختبارات (مثل in-memory أو مسار مؤقت)
  Future<Database> initForTesting({String? customPath, bool inMemory = true}) async {
    await close();
    _initCompleter = null;
    final db = await _initDatabase(customPath: customPath, inMemory: inMemory);
    _database = db;
    return db;
  }

  /// التحقق مما إذا كانت قاعدة البيانات مفتوحة
  bool get isOpen => _database != null && _database!.isOpen;

  /// إغلاق قاعدة البيانات بأمان
  Future<void> close() async {
    _initCompleter = null;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
