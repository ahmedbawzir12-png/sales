import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/exceptions.dart';
import 'package:sales/features/products/data/repositories/categories_repository_impl.dart';
import 'package:sales/features/products/data/repositories/products_repository_impl.dart';
import 'package:sales/features/products/data/repositories/stock_movements_repository_impl.dart';
import 'package:sales/features/products/data/repositories/units_repository_impl.dart';
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

  group('ProductsRepository Tests', () {
    test('إنشاء منتج صحيح مع مخزون أولي يسجل الحركة الافتتاحية تلقائياً', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final productsRepo = ProductsRepositoryImpl();
      final movementsRepo = StockMovementsRepositoryImpl();
      final catsRepo = CategoriesRepositoryImpl();
      final unitsRepo = UnitsRepositoryImpl();

      final category = (await catsRepo.getCategories()).first;
      final unit = (await unitsRepo.getUnits()).first;

      final newProduct = Product(
        id: 0,
        name: 'مخدة فندقية مايكروفايبر',
        categoryId: category.id,
        unitId: unit.id,
        purchasePrice: 2500,
        salePrice: 4000,
        minimumStock: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await productsRepo.createProduct(
        newProduct,
        initialStock: 10.0,
        initialStockNotes: 'رصيد افتتاحي لبداية التشغيل',
      );

      expect(created.id, greaterThan(0));
      expect(created.currentStock, equals(10.0));

      // التحقق من إنشاء سجل حركة المخزون الافتتاحي تلقائياً
      final movements = await movementsRepo.getMovementsByProductId(created.id);
      expect(movements.length, equals(1));
      expect(movements.first.movementType, equals(StockMovementType.initialStock));
      expect(movements.first.quantity, equals(10.0));
      expect(movements.first.stockBefore, equals(0.0));
      expect(movements.first.stockAfter, equals(10.0));
    });

    test('يرفض إنشاء منتج ببيانات غير صالحة (اسم فارغ، أسعار سالبة)', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = ProductsRepositoryImpl();

      final invalidName = Product(
        id: 0,
        name: '   ',
        categoryId: 1,
        unitId: 1,
        purchasePrice: 1000,
        salePrice: 2000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repo.createProduct(invalidName),
        throwsA(isA<ValidationException>()),
      );

      final negativePrice = invalidName.copyWith(
        name: 'طقم كنب',
        purchasePrice: -500,
      );

      expect(
        () => repo.createProduct(negativePrice),
        throwsA(isA<ValidationException>()),
      );
    });

    test('تعديل المنتج لا يقوم بتعديل كمية المخزون مباشرة', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = ProductsRepositoryImpl();

      final created = await repo.createProduct(
        Product(
          id: 0,
          name: 'سجادة حرير تركية',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 15000,
          salePrice: 25000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 8.0,
      );

      // محاولة تعديل الاسم والسعر
      final toUpdate = created.copyWith(
        name: 'سجادة حرير تركية فاخرة 2×3',
        salePrice: 27000,
        currentStock: 999.0, // لن يتم اعتماد هذه القيمة
      );

      await repo.updateProduct(toUpdate);

      final fetched = await repo.getProductById(created.id);
      expect(fetched.name, equals('سجادة حرير تركية فاخرة 2×3'));
      expect(fetched.salePrice, equals(27000));
      expect(fetched.currentStock, equals(8.0)); // بقي المخزون ثابتاً 8 كما هو!
    });

    test('تعطيل وتفعيل المنتج يحافظ على البيانات التاريخية', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = ProductsRepositoryImpl();

      final created = await repo.createProduct(
        Product(
          id: 0,
          name: 'ستارة شيفون مطرزة',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 5000,
          salePrice: 8000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repo.setProductActive(created.id, false);
      final deactivated = await repo.getProductById(created.id);
      expect(deactivated.isActive, isFalse);

      // يظهر عند طلب الكل ولا يظهر عند طلب النشطة فقط
      final activeOnly = await repo.getProducts(onlyActive: true);
      expect(activeOnly.any((p) => p.id == created.id), isFalse);

      final allProducts = await repo.getProducts(onlyActive: false);
      expect(allProducts.any((p) => p.id == created.id), isTrue);
    });

    test('البحث والتصفية بالاسم والتصنيف والنواقص يعمل بدقة', () async {
      await DatabaseService.instance.initForTesting(inMemory: true);
      final repo = ProductsRepositoryImpl();

      await repo.createProduct(
        Product(
          id: 0,
          name: 'بطانية صوف مفرد',
          categoryId: 1,
          unitId: 1,
          purchasePrice: 4000,
          salePrice: 6000,
          minimumStock: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 2.0, // منخفض المخزون
      );

      await repo.createProduct(
        Product(
          id: 0,
          name: 'لحاف شتوي مزدوج',
          categoryId: 2,
          unitId: 1,
          purchasePrice: 12000,
          salePrice: 18000,
          minimumStock: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        initialStock: 10.0, // مخزون متوفر
      );

      // بحث بالاسم
      final searchResults = await repo.getProducts(searchQuery: 'بطانية');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, contains('بطانية'));

      // تصفية النواقص
      final lowStockResults = await repo.getProducts(onlyLowStock: true);
      expect(lowStockResults.length, equals(1));
      expect(lowStockResults.first.name, contains('بطانية'));
      expect(await repo.getLowStockCount(), equals(1));
    });
  });
}
