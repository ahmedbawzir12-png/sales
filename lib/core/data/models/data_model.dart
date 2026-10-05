import '../../domain/entities/entity.dart';

/// الأساس المرجعي لجميع نماذج طبقة البيانات (Data Models)
abstract class DataModel<E extends Entity> {
  const DataModel();

  /// تحويل النموذج إلى خريطة بيانات مناسبة لـ SQLite
  Map<String, dynamic> toMap();

  /// تحويل النموذج إلى كيان النطاق المقابل
  E toEntity();
}
