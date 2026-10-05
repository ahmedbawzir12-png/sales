import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import '../../domain/entities/unit_of_measurement.dart';
import '../../domain/repositories/units_repository.dart';
import '../models/unit_model.dart';

/// تطبيق مستودع وحدات القياس باستخدام SQLite
class UnitsRepositoryImpl implements UnitsRepository {
  final DatabaseService _databaseService;

  UnitsRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<List<UnitOfMeasurement>> getUnits() async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableUnits,
        orderBy: 'name ASC',
      );

      return results.map((map) => UnitModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع وحدات القياس', e);
    }
  }

  @override
  Future<UnitOfMeasurement> getUnitById(int id) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableUnits,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) {
        throw const NotFoundException('وحدة القياس غير موجودة في النظام');
      }

      return UnitModel.fromMap(results.first).toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بيانات وحدة القياس', e);
    }
  }

  @override
  Future<int> createUnit(UnitOfMeasurement unit) async {
    final trimmedName = unit.name.trim();
    final trimmedSymbol = unit.symbol.trim();

    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم وحدة القياس مطلوب');
    }
    if (trimmedSymbol.isEmpty) {
      throw const ValidationException('رمز وحدة القياس مطلوب');
    }

    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final model = UnitModel(
        id: 0,
        name: trimmedName,
        symbol: trimmedSymbol,
        createdAt: now,
      );

      return await db.insert(
        DatabaseConstants.tableUnits,
        model.toMap(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء وحدة القياس الجديدة', e);
    }
  }

  @override
  Future<void> updateUnit(UnitOfMeasurement unit) async {
    final trimmedName = unit.name.trim();
    final trimmedSymbol = unit.symbol.trim();

    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم وحدة القياس مطلوب');
    }
    if (trimmedSymbol.isEmpty) {
      throw const ValidationException('رمز وحدة القياس مطلوب');
    }

    try {
      final db = await _databaseService.database;

      final rowsAffected = await db.update(
        DatabaseConstants.tableUnits,
        {
          'name': trimmedName,
          'symbol': trimmedSymbol,
        },
        where: 'id = ?',
        whereArgs: [unit.id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('وحدة القياس المطلوب تعديلها غير موجودة');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعديل بيانات وحدة القياس', e);
    }
  }

  @override
  Future<int> getProductsCountByUnit(int unitId) async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseConstants.tableProducts} WHERE unit_id = ?',
        [unitId],
      );
      if (results.isEmpty) return 0;
      return (results.first.values.first as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب المنتجات المرتبطة بوحدة القياس', e);
    }
  }
}
