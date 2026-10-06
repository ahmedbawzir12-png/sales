import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_movements_repository.dart';
import '../models/stock_movement_model.dart';

/// تطبيق مستودع حركات المخزون مع ضمان الذرية (Atomicity) ومنع الرصيد السالب
class StockMovementsRepositoryImpl implements StockMovementsRepository {
  final DatabaseService _databaseService;

  StockMovementsRepositoryImpl({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Future<List<StockMovement>> getMovementsByProductId(int productId) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableStockMovements,
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'created_at DESC, id DESC',
      );

      return results.map((map) => StockMovementModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع حركات مخزون المنتج', e);
    }
  }

  @override
  Future<List<StockMovement>> getAllMovements({int limit = 50, int offset = 0}) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        DatabaseConstants.tableStockMovements,
        orderBy: 'created_at DESC, id DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((map) => StockMovementModel.fromMap(map).toEntity()).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع سجل حركات المخزون', e);
    }
  }

  @override
  Future<StockMovement> recordMovement({
    required int productId,
    required StockMovementType type,
    required double quantity,
    required String reason,
    String? notes,
    String? reference,
  }) async {
    try {
      final db = await _databaseService.database;
      return await db.transaction<StockMovement>((txn) async {
        return await recordMovementWithExecutor(
          txn,
          productId: productId,
          type: type,
          quantity: quantity,
          reason: reason,
          notes: notes,
          reference: reference,
        );
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تسجيل حركة المخزون وتحديث الرصيد', e);
    }
  }

  /// تسجيل حركة المخزون باستخدام منفذ معاملات محدد (DatabaseExecutor)
  /// يتيح هذا التضمين السلس داخل معاملات أكبر مثل فواتير الشراء دون تكرار
  Future<StockMovement> recordMovementWithExecutor(
    DatabaseExecutor executor, {
    required int productId,
    required StockMovementType type,
    required double quantity,
    required String reason,
    String? notes,
    String? reference,
  }) async {
    if (quantity <= 0) {
      throw const ValidationException('كمية الحركة يجب أن تكون أكبر من الصفر');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const ValidationException('سبب حركة المخزون مطلوب ولا يمكن تركه فارغاً');
    }

    // 1. جلب رصيد المنتج الحالي مع قفل السجل
    final productRows = await executor.query(
      DatabaseConstants.tableProducts,
      columns: ['id', 'name', 'current_stock'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (productRows.isEmpty) {
      throw const NotFoundException('المنتج المحدد غير موجود في النظام');
    }

    final stockBefore = (productRows.first['current_stock'] as num).toDouble();
    final productName = productRows.first['name'] as String;

    // 2. حساب الرصيد الجديد بناءً على نوع الحركة
    final double stockAfter;
    if (type.isAddition) {
      stockAfter = stockBefore + quantity;
    } else {
      stockAfter = stockBefore - quantity;
    }

    // 3. التحقق الصارم من منع الرصيد السالب
    if (stockAfter < 0) {
      throw ValidationException(
        'لا يمكن إتمام العملية: الرصيد الحالي للمنتج "$productName" هو ($stockBefore) والمطلوب خصمه ($quantity)، مما يؤدي لرصيد سالب.',
      );
    }

    final now = DateTime.now().toIso8601String();

    // 4. تحديث رصيد المنتج
    await executor.update(
      DatabaseConstants.tableProducts,
      {
        'current_stock': stockAfter,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );

    // 5. تسجيل الحركة في جدول Stock Movement
    final movementModel = StockMovementModel(
      id: 0,
      productId: productId,
      movementType: type.name,
      quantity: quantity,
      stockBefore: stockBefore,
      stockAfter: stockAfter,
      reason: trimmedReason,
      notes: notes?.trim(),
      reference: reference?.trim(),
      createdAt: now,
    );

    final movementId = await executor.insert(
      DatabaseConstants.tableStockMovements,
      movementModel.toMap(),
    );

    return StockMovement(
      id: movementId,
      productId: productId,
      movementType: type,
      quantity: quantity,
      stockBefore: stockBefore,
      stockAfter: stockAfter,
      reason: trimmedReason,
      notes: notes?.trim(),
      reference: reference?.trim(),
      createdAt: DateTime.parse(now),
    );
  }

  @override
  Future<StockMovement?> adjustStock({
    required int productId,
    required double actualPhysicalStock,
    required String reason,
    String? notes,
  }) async {
    if (actualPhysicalStock < 0) {
      throw const ValidationException('الكمية الفعلية للجرد لا يمكن أن تكون سالبة');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const ValidationException('سبب التسوية الجردية مطلوب لتسجيل الملاحظة المحاسبية');
    }

    try {
      final db = await _databaseService.database;

      return await db.transaction<StockMovement?>((txn) async {
        final productRows = await txn.query(
          DatabaseConstants.tableProducts,
          columns: ['id', 'name', 'current_stock'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw const NotFoundException('المنتج المحدد غير موجود لإجراء الجرد');
        }

        final stockBefore = (productRows.first['current_stock'] as num).toDouble();
        final difference = actualPhysicalStock - stockBefore;

        // إذا لم يكن هناك فرق بين المسجل والفعلي فلا داعي لتسجيل حركة تسوية
        if (difference.abs() < 0.0001) {
          return null;
        }

        final StockMovementType type;
        final double movementQuantity;

        if (difference > 0) {
          type = StockMovementType.adjustmentIncrease;
          movementQuantity = difference;
        } else {
          type = StockMovementType.adjustmentDecrease;
          movementQuantity = difference.abs();
        }

        final now = DateTime.now().toIso8601String();

        // تحديث رصيد المنتج للكمية الفعلية
        await txn.update(
          DatabaseConstants.tableProducts,
          {
            'current_stock': actualPhysicalStock,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [productId],
        );

        // تسجيل حركة التسوية
        final movementModel = StockMovementModel(
          id: 0,
          productId: productId,
          movementType: type.name,
          quantity: movementQuantity,
          stockBefore: stockBefore,
          stockAfter: actualPhysicalStock,
          reason: trimmedReason,
          notes: notes?.trim(),
          reference: 'تسوية جردية بتاريخ ${now.substring(0, 10)}',
          createdAt: now,
        );

        final movementId = await txn.insert(
          DatabaseConstants.tableStockMovements,
          movementModel.toMap(),
        );

        final movement = StockMovement(
          id: movementId,
          productId: productId,
          movementType: type,
          quantity: movementQuantity,
          stockBefore: stockBefore,
          stockAfter: actualPhysicalStock,
          reason: trimmedReason,
          notes: notes?.trim(),
          reference: movementModel.reference,
          createdAt: DateTime.parse(now),
        );

        AppDataNotifier.instance.notifyInventoryChanged();

        return movement;
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تنفيذ التسوية الجردية', e);
    }
  }
}
