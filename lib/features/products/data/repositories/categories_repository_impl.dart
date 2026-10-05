import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/categories_repository.dart';
import '../models/category_model.dart';

/// تطبيق مستودع التصنيفات باستخدام SQLite
class CategoriesRepositoryImpl implements CategoriesRepository {
  final DatabaseService _databaseService;

  CategoriesRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<List<Category>> getCategories({bool? onlyActive}) async {
    try {
      final db = await _databaseService.database;
      final whereClause = onlyActive == true ? 'is_active = 1' : null;

      final results = await db.query(
        DatabaseConstants.tableCategories,
        where: whereClause,
        orderBy: 'name ASC',
      );

      return results.map((map) => CategoryModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة التصنيفات', e);
    }
  }

  @override
  Future<Category> getCategoryById(int id) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableCategories,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) {
        throw const NotFoundException('التصنيف غير موجود في النظام');
      }

      return CategoryModel.fromMap(results.first).toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بيانات التصنيف', e);
    }
  }

  @override
  Future<int> createCategory(Category category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم التصنيف مطلوب ولا يمكن أن يكون فارغاً');
    }

    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final model = CategoryModel(
        id: 0,
        name: trimmedName,
        description: category.description?.trim(),
        isActive: category.isActive ? 1 : 0,
        createdAt: now,
        updatedAt: now,
      );

      return await db.insert(
        DatabaseConstants.tableCategories,
        model.toMap(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء التصنيف الجديد', e);
    }
  }

  @override
  Future<void> updateCategory(Category category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم التصنيف مطلوب ولا يمكن أن يكون فارغاً');
    }

    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        DatabaseConstants.tableCategories,
        {
          'name': trimmedName,
          'description': category.description?.trim(),
          'is_active': category.isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [category.id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('التصنيف المطلوب تعديله غير موجود');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعديل بيانات التصنيف', e);
    }
  }

  @override
  Future<void> setCategoryActive(int id, bool isActive) async {
    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        DatabaseConstants.tableCategories,
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('التصنيف غير موجود لتغيير حالته');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تحديث حالة التصنيف', e);
    }
  }

  @override
  Future<int> getProductsCountByCategory(int categoryId) async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseConstants.tableProducts} WHERE category_id = ?',
        [categoryId],
      );
      if (results.isEmpty) return 0;
      return (results.first.values.first as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب المنتجات المرتبطة بالتصنيف', e);
    }
  }
}
