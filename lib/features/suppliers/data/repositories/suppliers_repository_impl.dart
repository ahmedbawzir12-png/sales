import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../models/supplier_model.dart';

/// تطبيق مستودع الموردين باستخدام SQLite
class SuppliersRepositoryImpl implements SuppliersRepository {
  final DatabaseService _databaseService;

  SuppliersRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<List<Supplier>> getSuppliers({String? searchQuery, bool? onlyActive}) async {
    try {
      final db = await _databaseService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClauses.add('(name LIKE ? OR phone LIKE ?)');
        final queryPattern = '%${searchQuery.trim()}%';
        whereArgs.add(queryPattern);
        whereArgs.add(queryPattern);
      }

      if (onlyActive == true) {
        whereClauses.add('is_active = 1');
      }

      final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final results = await db.rawQuery('''
        SELECT * FROM ${DatabaseConstants.tableSuppliers}
        $whereString
        ORDER BY is_active DESC, name ASC
      ''', whereArgs);

      return results.map((map) => SupplierModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة الموردين', e);
    }
  }

  @override
  Future<Supplier> getSupplierById(int id) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableSuppliers,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) {
        throw const NotFoundException('المورد المطلوب غير مسجل في النظام');
      }

      return SupplierModel.fromMap(results.first).toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بيانات المورد', e);
    }
  }

  @override
  Future<Supplier> createSupplier(Supplier supplier) async {
    final trimmedName = supplier.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم المورد مطلوب ولا يمكن أن يكون فارغاً');
    }

    try {
      final db = await _databaseService.database;

      // التحقق من عدم تكرار الاسم
      final existing = await db.query(
        DatabaseConstants.tableSuppliers,
        where: 'name = ?',
        whereArgs: [trimmedName],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        throw ValidationException('يوجد مورد مسجل بالفعل بنفس الاسم "$trimmedName"');
      }

      final now = DateTime.now().toIso8601String();
      final model = SupplierModel(
        id: 0,
        name: trimmedName,
        phone: supplier.phone?.trim(),
        whatsapp: supplier.whatsapp?.trim(),
        address: supplier.address?.trim(),
        notes: supplier.notes?.trim(),
        currentBalance: 0,
        isActive: supplier.isActive ? 1 : 0,
        createdAt: now,
        updatedAt: now,
      );

      final id = await db.insert(
        DatabaseConstants.tableSuppliers,
        model.toMap(),
      );

      return supplier.copyWith(
        id: id,
        name: trimmedName,
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل المورد الجديد', e);
    }
  }

  @override
  Future<void> updateSupplier(Supplier supplier) async {
    final trimmedName = supplier.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم المورد مطلوب ولا يمكن أن يكون فارغاً');
    }

    try {
      final db = await _databaseService.database;

      // التحقق من عدم التكرار مع مورد آخر
      final existing = await db.query(
        DatabaseConstants.tableSuppliers,
        where: 'name = ? AND id != ?',
        whereArgs: [trimmedName, supplier.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        throw ValidationException('يوجد مورد آخر مسجل بهذا الاسم "$trimmedName"');
      }

      final now = DateTime.now().toIso8601String();
      final rowsAffected = await db.update(
        DatabaseConstants.tableSuppliers,
        {
          'name': trimmedName,
          'phone': supplier.phone?.trim(),
          'whatsapp': supplier.whatsapp?.trim(),
          'address': supplier.address?.trim(),
          'notes': supplier.notes?.trim(),
          'is_active': supplier.isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [supplier.id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('المورد المطلوب تعديله غير موجود في النظام');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعديل بيانات المورد', e);
    }
  }

  @override
  Future<void> setSupplierActive(int id, bool isActive) async {
    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        DatabaseConstants.tableSuppliers,
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('المورد غير موجود لتغيير حالته');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تغيير حالة تفعيل المورد', e);
    }
  }

  @override
  Future<int> getTotalSuppliersDebt() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery('''
        SELECT SUM(current_balance) FROM ${DatabaseConstants.tableSuppliers}
        WHERE is_active = 1 AND current_balance > 0
      ''');

      if (results.isEmpty || results.first.values.first == null) {
        return 0;
      }
      return (results.first.values.first as num).toInt();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل احتساب إجمالي ديون الموردين', e);
    }
  }

  @override
  Future<int> getActiveSuppliersCount() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery('''
        SELECT COUNT(*) FROM ${DatabaseConstants.tableSuppliers}
        WHERE is_active = 1
      ''');

      if (results.isEmpty) return 0;
      return (results.first.values.first as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل احتساب عدد الموردين النشطين', e);
    }
  }
}
