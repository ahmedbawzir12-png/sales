import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/features/products/domain/entities/category.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/entities/unit_of_measurement.dart';
import 'package:sales/features/products/domain/repositories/categories_repository.dart';
import 'package:sales/features/products/domain/repositories/products_repository.dart';
import 'package:sales/features/products/domain/repositories/units_repository.dart';
import 'package:sales/features/products/presentation/screens/quick_add_product_dialog.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_item.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_status.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/purchases/domain/repositories/purchases_repository.dart';
import 'package:sales/features/purchases/presentation/screens/new_purchase_invoice_screen.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
import 'package:sales/features/suppliers/domain/repositories/suppliers_repository.dart';

class FakeCategoriesRepository implements CategoriesRepository {
  final List<Category> categories = [
    Category(
      id: 1,
      name: 'مفروشات غرف نوم',
      description: '',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Category>> getCategories({bool? onlyActive}) async => categories;
  @override
  Future<Category> getCategoryById(int id) async => categories.firstWhere((c) => c.id == id);
  @override
  Future<int> createCategory(Category category) async => category.id;
  @override
  Future<void> updateCategory(Category category) async {}
  @override
  Future<void> setCategoryActive(int id, bool isActive) async {}
  @override
  Future<int> getProductsCountByCategory(int categoryId) async => 0;
}

class FakeUnitsRepository implements UnitsRepository {
  final List<UnitOfMeasurement> units = [
    UnitOfMeasurement(
      id: 1,
      name: 'قطعة',
      symbol: 'قطعة',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<UnitOfMeasurement>> getUnits() async => units;
  @override
  Future<UnitOfMeasurement> getUnitById(int id) async => units.firstWhere((u) => u.id == id);
  @override
  Future<int> createUnit(UnitOfMeasurement unit) async => unit.id;
  @override
  Future<void> updateUnit(UnitOfMeasurement unit) async {}
  @override
  Future<int> getProductsCountByUnit(int unitId) async => 0;
}

class FakeProductsRepository implements ProductsRepository {
  final List<Product> products;
  Product? lastCreatedProduct;
  double? lastInitialStock;

  FakeProductsRepository({List<Product>? initialProducts})
      : products = initialProducts ?? [
          Product(
            id: 1,
            name: 'كنب مودرن رمادي',
            categoryId: 1,
            categoryName: 'مفروشات غرف نوم',
            unitId: 1,
            unitSymbol: 'قطعة',
            purchasePrice: 40000,
            salePrice: 55000,
            currentStock: 10.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    int? categoryId,
    bool? onlyActive,
    bool? onlyLowStock,
  }) async {
    return products;
  }

  @override
  Future<Product> getProductById(int id) async {
    return products.firstWhere((p) => p.id == id);
  }

  @override
  Future<Product> createProduct(
    Product product, {
    double initialStock = 0.0,
    String? initialStockNotes,
  }) async {
    lastInitialStock = initialStock;
    final newId = products.length + 1;
    final created = Product(
      id: newId,
      name: product.name,
      categoryId: product.categoryId,
      categoryName: 'مفروشات غرف نوم',
      unitId: product.unitId,
      unitSymbol: 'قطعة',
      purchasePrice: product.purchasePrice,
      salePrice: product.salePrice,
      currentStock: initialStock,
      minimumStock: product.minimumStock,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    products.add(created);
    lastCreatedProduct = created;
    return created;
  }

  @override
  Future<void> updateProduct(Product product) async {}
  @override
  Future<void> setProductActive(int id, bool isActive) async {}
  @override
  Future<int> getLowStockCount() async => 0;
}

class FakeSuppliersRepository implements SuppliersRepository {
  final List<Supplier> suppliers = [
    Supplier(
      id: 1,
      name: 'شركة المفروشات المتحدة',
      phone: '777000111',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Supplier>> getSuppliers({String? searchQuery, bool? onlyActive}) async => suppliers;
  @override
  Future<Supplier> getSupplierById(int id) async => suppliers.firstWhere((s) => s.id == id);
  @override
  Future<Supplier> createSupplier(Supplier supplier) async => supplier;
  @override
  Future<void> updateSupplier(Supplier supplier) async {}
  @override
  Future<void> setSupplierActive(int id, bool isActive) async {}
  @override
  Future<int> getTotalSuppliersDebt() async => 0;
  @override
  Future<int> getActiveSuppliersCount() async => suppliers.length;
}

class FakePurchasesRepository implements PurchasesRepository {
  @override
  Future<String> generateNextInvoiceNumber() async => 'PUR-2026-0001';

  @override
  Future<PurchaseInvoice> createPurchaseInvoice({
    required PurchaseInvoice invoice,
    required List<PurchaseInvoiceItem> items,
  }) async {
    return invoice;
  }

  @override
  Future<List<PurchaseInvoice>> getInvoices({
    String? searchQuery,
    int? supplierId,
    PurchasePaymentType? paymentType,
    PurchaseInvoiceStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async => [];

  @override
  Future<PurchaseInvoice> getInvoiceById(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelPurchaseInvoice(int invoiceId, {required String reason}) async {}
}

void main() {
  group('اختبارات الإضافة السريعة للمنتجات في شاشة المشتريات (Quick Add & Autocomplete)', () {
    testWidgets('حوار الإضافة السريعة: يحفظ المنتج برصيد أولي صفر وبدون طلب كمية من المستخدم', (tester) async {
      final productsRepo = FakeProductsRepository();
      final categoriesRepo = FakeCategoriesRepository();
      final unitsRepo = FakeUnitsRepository();

      Product? createdProduct;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  createdProduct = await QuickAddProductDialog.show(
                    context,
                    initialName: 'طقم طاولات ضيافة تركي',
                    initialPurchasePrice: 25000,
                    productsRepository: productsRepo,
                    categoriesRepository: categoriesRepo,
                    unitsRepository: unitsRepo,
                  );
                },
                child: const Text('فتح الحوار'),
              ),
            ),
          ),
        ),
      );

      // النقر على زر فتح الحوار
      await tester.tap(find.text('فتح الحوار'));
      await tester.pumpAndSettle();

      // التحقق من ظهور الحوار والبيانات الأساسية
      expect(find.text('تعريف منتج جديد سريعاً'), findsOneWidget);
      expect(find.text('طقم طاولات ضيافة تركي'), findsOneWidget);
      expect(find.text('25000'), findsAtLeastNWidgets(1));

      // التأكد من عدم طلب رصيد/كمية في واجهة المنتج لأنها ستورد عبر الفاتورة
      expect(find.text('الرصيد الافتتاحي'), findsNothing);
      expect(find.textContaining('برصيد 0، وستُسجل كميته المشتراة تلقائياً في المخزون فور حفظ الفاتورة'), findsOneWidget);

      // حفظ وإدراج المنتج
      await tester.tap(find.text('حفظ وإدراج في الفاتورة'));
      await tester.pumpAndSettle();

      // التحقق من نتائج الحفظ
      expect(createdProduct, isNotNull);
      expect(createdProduct!.name, 'طقم طاولات ضيافة تركي');
      expect(createdProduct!.purchasePrice, 25000);
      expect(createdProduct!.currentStock, 0.0);
      expect(productsRepo.lastInitialStock, 0.0);
    });

    testWidgets('شاشة فاتورة الشراء: حقل الإكمال التلقائي يعرض خيار الإضافة السريعة عند كتابة اسم صنف جديد', (tester) async {
      final purchasesRepo = FakePurchasesRepository();
      final suppliersRepo = FakeSuppliersRepository();
      final productsRepo = FakeProductsRepository();
      final categoriesRepo = FakeCategoriesRepository();
      final unitsRepo = FakeUnitsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: NewPurchaseInvoiceScreen(
            purchasesRepository: purchasesRepo,
            suppliersRepository: suppliersRepo,
            productsRepository: productsRepo,
            categoriesRepository: categoriesRepo,
            unitsRepository: unitsRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // البحث عن حقل البحث والإكمال التلقائي للصنف الأول
      final productSearchFinder = find.widgetWithText(TextFormField, 'المنتج #1 *');
      expect(productSearchFinder, findsOneWidget);

      // كتابة اسم صنف جديد غير مسجل في النظام
      await tester.enterText(productSearchFinder, 'غرفة نوم أطفال مودرن');
      await tester.pumpAndSettle();

      // التحقق من ظهور خيار الإضافة السريعة في القائمة المنسدلة
      final quickAddTileFinder = find.textContaining('إضافة "غرفة نوم أطفال مودرن" كمنتج جديد');
      expect(quickAddTileFinder, findsOneWidget);

      // الضغط على خيار الإضافة السريعة
      await tester.tap(quickAddTileFinder);
      await tester.pumpAndSettle();

      // التأكد من فتح حوار QuickAddProductDialog وتعبئة الاسم المكتوب
      expect(find.text('تعريف منتج جديد سريعاً'), findsOneWidget);
      expect(find.text('غرفة نوم أطفال مودرن'), findsAtLeastNWidgets(1));

      // الضغط على حفظ وإدراج في الفاتورة
      await tester.tap(find.text('حفظ وإدراج في الفاتورة'));
      await tester.pumpAndSettle();

      // التحقق من حفظ المنتج برصيد 0 وإدراجه فوراً في سطر الفاتورة
      expect(productsRepo.lastCreatedProduct, isNotNull);
      expect(productsRepo.lastCreatedProduct!.name, 'غرفة نوم أطفال مودرن');
      expect(productsRepo.lastInitialStock, 0.0);

      // التأكد من أن حقل الصنف في الفاتورة أصبح محدداً بالمنتج الجديد
      expect(find.widgetWithText(TextFormField, 'غرفة نوم أطفال مودرن'), findsOneWidget);
    });
  });
}
