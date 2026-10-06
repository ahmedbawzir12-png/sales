import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/products_repository.dart';
import '../models/product_model.dart';
import '../models/stock_movement_model.dart';

/// تطبيق مستودع المنتجات باستخدام SQLite مع الربط المحكم بحركات المخزون
class ProductsRepositoryImpl implements ProductsRepository {
  final DatabaseService _databaseService;

  ProductsRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    int? categoryId,
    bool? onlyActive,
    bool? onlyLowStock,
  }) async {
    try {
      final db = await _databaseService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClauses.add('p.name LIKE ?');
        whereArgs.add('%${searchQuery.trim()}%');
      }

      if (categoryId != null && categoryId > 0) {
        whereClauses.add('p.category_id = ?');
        whereArgs.add(categoryId);
      }

      if (onlyActive == true) {
        whereClauses.add('p.is_active = 1');
      }

      if (onlyLowStock == true) {
        whereClauses.add('p.is_active = 1 AND p.current_stock <= p.minimum_stock');
      }

      final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final query = '''
        SELECT 
          p.*,
          c.name AS category_name,
          u.symbol AS unit_symbol
        FROM ${DatabaseConstants.tableProducts} p
        LEFT JOIN ${DatabaseConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        $whereString
        ORDER BY p.is_active DESC, p.name ASC
      ''';

      final results = await db.rawQuery(query, whereArgs);
      return results.map((map) => ProductModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة المنتجات', e);
    }
  }

  @override
  Future<Product> getProductById(int id) async {
    try {
      final db = await _databaseService.database;

      final query = '''
        SELECT 
          p.*,
          c.name AS category_name,
          u.symbol AS unit_symbol
        FROM ${DatabaseConstants.tableProducts} p
        LEFT JOIN ${DatabaseConstants.tableCategories} c ON p.category_id = c.id
        LEFT JOIN ${DatabaseConstants.tableUnits} u ON p.unit_id = u.id
        WHERE p.id = ?
        LIMIT 1
      ''';

      final results = await db.rawQuery(query, [id]);
      if (results.isEmpty) {
        throw const NotFoundException('المنتج المطلوب غير موجود في النظام');
      }

      return ProductModel.fromMap(results.first).toEntity();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع تفاصيل المنتج', e);
    }
  }

  @override
  Future<Product> createProduct(
    Product product, {
    double initialStock = 0.0,
    String? initialStockNotes,
  }) async {
    final trimmedName = product.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم المنتج مطلوب ولا يمكن أن يكون فارغاً');
    }
    if (product.categoryId <= 0) {
      throw const ValidationException('يرجى اختيار تصنيف صالح للمنتج');
    }
    if (product.unitId <= 0) {
      throw const ValidationException('يرجى اختيار وحدة قياس صالحة للمنتج');
    }
    if (product.purchasePrice < 0) {
      throw const ValidationException('سعر الشراء لا يمكن أن يكون سالباً');
    }
    if (product.salePrice < 0) {
      throw const ValidationException('سعر البيع لا يمكن أن يكون سالباً');
    }
    if (initialStock < 0) {
      throw const ValidationException('المخزون الافتتاحي لا يمكن أن يكون سالباً');
    }
    if (product.minimumStock < 0) {
      throw const ValidationException('الحد الأدنى لإعادة الطلب لا يمكن أن يكون سالباً');
    }

    try {
      final db = await _databaseService.database;

      // تنفيذ إضافة المنتج وحركة المخزون الأولي داخل Transaction ذرية
      return await db.transaction<Product>((txn) async {
        final now = DateTime.now().toIso8601String();

        final productModel = ProductModel(
          id: 0,
          name: trimmedName,
          categoryId: product.categoryId,
          unitId: product.unitId,
          purchasePrice: product.purchasePrice,
          salePrice: product.salePrice,
          currentStock: initialStock,
          minimumStock: product.minimumStock,
          description: product.description?.trim(),
          isActive: product.isActive ? 1 : 0,
          createdAt: now,
          updatedAt: now,
        );

        final productId = await txn.insert(
          DatabaseConstants.tableProducts,
          productModel.toMap(),
        );

        // إذا كان هناك مخزون أولي، يتم تسجيل حركة المخزون الافتتاحي
        if (initialStock > 0) {
          final movementModel = StockMovementModel(
            id: 0,
            productId: productId,
            movementType: StockMovementType.initialStock.name,
            quantity: initialStock,
            stockBefore: 0.0,
            stockAfter: initialStock,
            reason: 'رصيد مخزون افتتاحي عند إنشاء المنتج',
            notes: initialStockNotes?.trim(),
            reference: 'افتتاحي-$productId',
            createdAt: now,
          );

          await txn.insert(
            DatabaseConstants.tableStockMovements,
            movementModel.toMap(),
          );
        }

        final created = product.copyWith(
          id: productId,
          name: trimmedName,
          currentStock: initialStock,
          averageCost: product.purchasePrice.toDouble(),
          createdAt: DateTime.parse(now),
          updatedAt: DateTime.parse(now),
        );

        AppDataNotifier.instance.notifyInventoryChanged();

        return created;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل إنشاء المنتج وحفظ رصيده الافتتاحي', e);
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    final trimmedName = product.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم المنتج مطلوب ولا يمكن أن يكون فارغاً');
    }
    if (product.categoryId <= 0) {
      throw const ValidationException('يرجى اختيار تصنيف صالح للمنتج');
    }
    if (product.unitId <= 0) {
      throw const ValidationException('يرجى اختيار وحدة قياس صالحة للمنتج');
    }
    if (product.purchasePrice < 0) {
      throw const ValidationException('سعر الشراء لا يمكن أن يكون سالباً');
    }
    if (product.salePrice < 0) {
      throw const ValidationException('سعر البيع لا يمكن أن يكون سالباً');
    }
    if (product.minimumStock < 0) {
      throw const ValidationException('الحد الأدنى لإعادة الطلب لا يمكن أن يكون سالباً');
    }

    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      // ملاحظة مهمة جداً: لا نعدل current_stock هنا أبداً، المخزون يُعدل فقط عبر حركات المخزون
      final rowsAffected = await db.update(
        DatabaseConstants.tableProducts,
        {
          'name': trimmedName,
          'category_id': product.categoryId,
          'unit_id': product.unitId,
          'purchase_price': product.purchasePrice,
          'sale_price': product.salePrice,
          'minimum_stock': product.minimumStock,
          'description': product.description?.trim(),
          'is_active': product.isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('المنتج المطلوب تعديله غير موجود في النظام');
      }

      AppDataNotifier.instance.notifyInventoryChanged();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعديل بيانات المنتج', e);
    }
  }

  @override
  Future<void> setProductActive(int id, bool isActive) async {
    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        DatabaseConstants.tableProducts,
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        throw const NotFoundException('المنتج غير موجود لتغيير حالته');
      }

      AppDataNotifier.instance.notifyInventoryChanged();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تغيير حالة تفعيل المنتج', e);
    }
  }

  @override
  Future<int> getLowStockCount() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseConstants.tableProducts} WHERE is_active = 1 AND current_stock <= minimum_stock',
      );
      if (results.isEmpty) return 0;
      return (results.first.values.first as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حساب المنتجات منخفضة المخزون', e);
    }
  }
}
