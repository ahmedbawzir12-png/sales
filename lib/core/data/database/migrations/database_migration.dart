import 'package:sqflite/sqflite.dart';

/// واجهة موحدة لجميع ملفات ترحيل وهجرة قاعدة البيانات (Migrations)
abstract class DatabaseMigration {
  /// رقم الإصدار الذي تطبقه هذه الهجرة
  int get version;

  /// وصف موجز للتغييرات
  String get description;

  /// تطبيق التغييرات على قاعدة البيانات
  Future<void> up(DatabaseExecutor db);

  /// التراجع عن التغييرات في حال الرجوع لإصدار سابق
  Future<void> down(DatabaseExecutor db);
}
