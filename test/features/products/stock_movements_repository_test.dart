import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/data/repositories/stock_movements_repository_impl.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/entities/stock_movement.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Stock Movements & Inventory Adjustments Tests (المخزون والجرد)', () {
    test('سلسلة الحركات: رصيد 10 -> إضافة 5 = 15 -> خصم 3 = 12 -> رفض خصم 20 لمنع السالب', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();
      final movementsRepo = StockMovementsRepositoryImpl();

      // 1. إنشاء منتج مع رصيد افتتاحي 10
      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'قماش ستائر فاخر بالامتار',
          categoryId: 1,
          unitId: 2, // متر
          purchasePrice: 1500,
          salePrice: 2500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0,
      );

      var current = await productsRepo.getProductById(product.id);
      expect(current.currentStock, equals(10.0));

      // 2. حركة إضافة 5 (مثلاً تسوية زيادة) -> يجب أن تصبح 15
      final addMovement = await movementsRepo.recordMovement(
        productId: product.id,
        type: StockMovementType.adjustmentIncrease,
        quantity: 5.0,
        reason: 'إضافة لفافات جديدة للمستودع',
      );

      expect(addMovement.stockBefore, equals(10.0));
      expect(addMovement.stockAfter, equals(15.0));

      current = await productsRepo.getProductById(product.id);
      expect(current.currentStock, equals(15.0));

      // 3. حركة خصم 3 -> يجب أن تصبح 12
      final deductMovement = await movementsRepo.recordMovement(
        productId: product.id,
        type: StockMovementType.adjustmentDecrease,
        quantity: 3.0,
        reason: 'تلف جزء من القماش',
      );

      expect(deductMovement.stockBefore, equals(15.0));
      expect(deductMovement.stockAfter, equals(12.0));

      current = await productsRepo.getProductById(product.id);
      expect(current.currentStock, equals(12.0));

      // 4. محاولة خصم 20 (والرصيد 12) -> يجب رفض العملية تماماً لحماية المخزون من السالب
      expect(
        () => movementsRepo.recordMovement(
          productId: product.id,
          type: StockMovementType.adjustmentDecrease,
          quantity: 20.0,
          reason: 'محاولة سحب تفوق الرصيد',
        ),
        throwsA(isA<ValidationException>()),
      );

      // التأكد من أن الرصيد لم يتأثر وبقي 12 كما هو
      current = await productsRepo.getProductById(product.id);
      expect(current.currentStock, equals(12.0));
    });

    test('الجرد الفعلي: النظام 12 -> الفعلي 10 -> يسجل حركة عجز (-2) ويصبح الرصيد 10', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();
      final movementsRepo = StockMovementsRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'طقم كنب تركي 5 مقاعد',
          categoryId: 1,
          unitId: 3, // طقم
          purchasePrice: 150000,
          salePrice: 220000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 12.0,
      );

      // تنفيذ جرد فعلي وتبين أن الكمية 10 فقط (عجز -2)
      final movement = await movementsRepo.adjustStock(
        productId: product.id,
        actualPhysicalStock: 10.0,
        reason: 'جرد نهاية الشهر الربع سنوي',
        notes: 'عجز طقمين بسبب نقل المعرض',
      );

      expect(movement, isNotNull);
      expect(movement!.movementType, equals(StockMovementType.adjustmentDecrease));
      expect(movement.quantity, equals(2.0));
      expect(movement.stockBefore, equals(12.0));
      expect(movement.stockAfter, equals(10.0));

      final updated = await productsRepo.getProductById(product.id);
      expect(updated.currentStock, equals(10.0));
    });

    test('الجرد الفعلي: زيادة عن رصيد النظام -> يسجل حركة زيادة (+3)', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();
      final movementsRepo = StockMovementsRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'مخدة فندقية ناعمة',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 1800,
          salePrice: 2800,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 20.0,
      );

      // وجد في المستودع 23 مخدة (فائض +3)
      final movement = await movementsRepo.adjustStock(
        productId: product.id,
        actualPhysicalStock: 23.0,
        reason: 'تصحيح كمية بعد عد فيزيائي يدوي',
      );

      expect(movement, isNotNull);
      expect(movement!.movementType, equals(StockMovementType.adjustmentIncrease));
      expect(movement.quantity, equals(3.0));
      expect(movement.stockBefore, equals(20.0));
      expect(movement.stockAfter, equals(23.0));

      final updated = await productsRepo.getProductById(product.id);
      expect(updated.currentStock, equals(23.0));
    });

    test('الذرية (Atomicity): فشل تسجيل الحركة داخل المعاملة يلغي أي تعديل على رصيد المنتج', () async {
      final db = await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'سجادة أرضية فخمة',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 10000,
          salePrice: 15000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 50.0,
      );

      // محاكاة معاملة تفشل بعد تعديل رصيد المنتج
      try {
        await db.transaction((txn) async {
          // تعديل رصيد المنتج أولاً
          await txn.update(
            DatabaseConstants.tableProducts,
            {'current_stock': 20.0},
            where: 'id = ?',
            whereArgs: [product.id],
          );

          // إثارة استثناء فوري لمحاكاة عطل أثناء كتابة سجل الحركة
          throw Exception('خطأ طارئ أثناء حفظ سجل حركة المخزون');
        });
      } catch (_) {
        // تم التقاط الخطأ
      }

      // التحقق من أن Rollback حدث وأن رصيد المنتج بقي 50 ولم يتغير إلى 20
      final verified = await productsRepo.getProductById(product.id);
      expect(verified.currentStock, equals(50.0));
    });

    test('دعم الكميات العشرية والكسور بدقة (مثل 2.5 متر قماش)', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();
      final movementsRepo = StockMovementsRepositoryImpl();

      final product = await productsRepo.createProduct(
        Product(
          id: 0,
          name: 'قماش حرير ستائر',
          categoryId: 1,
          unitId: 2,
          purchasePrice: 2000,
          salePrice: 3500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.5,
      );

      // خصم 2.5 متر
      final movement = await movementsRepo.recordMovement(
        productId: product.id,
        type: StockMovementType.adjustmentDecrease,
        quantity: 2.5,
        reason: 'قص عينة للعميل',
      );

      expect(movement.stockAfter, closeTo(8.0, 0.001));

      final updated = await productsRepo.getProductById(product.id);
      expect(updated.currentStock, closeTo(8.0, 0.001));
    });
  });
}
