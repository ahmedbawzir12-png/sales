import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../domain/entities/store_profile.dart';
import '../../domain/repositories/store_settings_repository.dart';
import '../mappers/store_profile_mapper.dart';
import '../models/store_profile_model.dart';

/// تطبيق مستودع إعدادات المتجر باستخدام خدمة قاعدة البيانات المحلية SQLite
class StoreSettingsRepositoryImpl implements StoreSettingsRepository {
  final DatabaseService _databaseService;

  StoreSettingsRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<StoreProfile> getStoreProfile() async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableStoreProfile,
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (results.isEmpty) {
        throw const NotFoundException('لم يتم العثور على بيانات المتجر الأساسية');
      }

      final model = StoreProfileModel.fromMap(results.first);
      return model.toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('حدث خطأ أثناء استرجاع بيانات المتجر', e);
    }
  }

  @override
  Future<void> updateStoreProfile(StoreProfile profile) async {
    try {
      final db = await _databaseService.database;
      final model = profile.toModel();

      final updatedRows = await db.update(
        DatabaseConstants.tableStoreProfile,
        model.toMap(),
        where: 'id = ?',
        whereArgs: [1],
      );

      if (updatedRows == 0) {
        // إذا لم يكن السجل موجوداً نقوم بإدراجه
        await db.insert(
          DatabaseConstants.tableStoreProfile,
          model.toMap(),
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('حدث خطأ أثناء تحديث بيانات المتجر', e);
    }
  }
}
