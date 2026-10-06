import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/features/customers/domain/entities/customer.dart';
import 'package:sales/features/customers/domain/repositories/customers_repository.dart';
import 'package:sales/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:sales/features/products/domain/entities/category.dart';
import 'package:sales/features/products/domain/entities/product.dart';
import 'package:sales/features/products/domain/repositories/categories_repository.dart';
import 'package:sales/features/products/domain/repositories/products_repository.dart';
import 'package:sales/features/products/presentation/screens/products_list_screen.dart';
import 'package:sales/features/suppliers/domain/entities/supplier.dart';
import 'package:sales/features/suppliers/domain/repositories/suppliers_repository.dart';
import 'package:sales/features/suppliers/presentation/screens/suppliers_list_screen.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice.dart';
import 'package:sales/features/sales/domain/entities/sales_payment_type.dart';
import 'package:sales/features/sales/domain/entities/sales_invoice_status.dart';
import 'package:sales/features/sales/domain/repositories/sales_repository.dart';
import 'package:sales/features/sales/presentation/screens/sales_list_screen.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice_status.dart';
import 'package:sales/features/purchases/domain/entities/purchase_payment_type.dart';
import 'package:sales/features/purchases/domain/repositories/purchases_repository.dart';
import 'package:sales/features/purchases/presentation/screens/purchases_list_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// --- Mocks / Fakes for testing instant search ---

class FakeCustomersRepository implements CustomersRepository {
  final List<Customer> allCustomers = [
    Customer(
      id: 1,
      name: 'أحمد علي',
      phone: '771111111',
      currentBalance: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Customer(
      id: 2,
      name: 'باسل محمود',
      phone: '772222222',
      currentBalance: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<Customer>> getCustomers({bool? onlyActive, String? searchQuery}) async {
    return allCustomers.where((c) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return c.name.contains(searchQuery) || (c.phone?.contains(searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProductsRepository implements ProductsRepository {
  final List<Product> allProducts = [
    Product(
      id: 1,
      name: 'أريكة جلدية',
      categoryId: 1,
      unitId: 1,
      purchasePrice: 1000,
      salePrice: 1500,
      currentStock: 10,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Product(
      id: 2,
      name: 'طاولة طعام',
      categoryId: 1,
      unitId: 1,
      purchasePrice: 800,
      salePrice: 1200,
      currentStock: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    int? categoryId,
    bool? onlyActive,
    bool? onlyLowStock,
  }) async {
    return allProducts.where((p) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return p.name.contains(searchQuery);
      }
      return true;
    }).toList();
  }

  @override
  Future<int> getLowStockCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCategoriesRepository implements CategoriesRepository {
  @override
  Future<List<Category>> getCategories({bool? onlyActive}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSuppliersRepository implements SuppliersRepository {
  final List<Supplier> allSuppliers = [
    Supplier(
      id: 1,
      name: 'أنور للتجارة',
      phone: '773333333',
      currentBalance: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Supplier(
      id: 2,
      name: 'سامي خليل',
      phone: '774444444',
      currentBalance: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<Supplier>> getSuppliers({String? searchQuery, bool? onlyActive}) async {
    return allSuppliers.where((s) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return s.name.contains(searchQuery) || (s.phone?.contains(searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  Future<int> getTotalSuppliersDebt() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSalesRepository implements SalesRepository {
  final List<SalesInvoice> allInvoices = [
    SalesInvoice(
      id: 1,
      invoiceNumber: 'INV-001',
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 1000,
      totalAmount: 1000,
      paidAmount: 1000,
      remainingAmount: 0,
      customerName: 'أحمد',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    SalesInvoice(
      id: 2,
      invoiceNumber: 'INV-002',
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 2000,
      totalAmount: 2000,
      paidAmount: 2000,
      remainingAmount: 0,
      customerName: 'سعيد',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<SalesInvoice>> getInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    SalesPaymentType? paymentType,
    SalesInvoiceStatus? status,
    String? searchQuery,
  }) async {
    return allInvoices.where((inv) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return inv.invoiceNumber.contains(searchQuery) ||
            (inv.customerName?.contains(searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getSalesSummaryMetrics({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
  }) async {
    return {
      'totalSales': 3000,
      'totalPaid': 3000,
      'totalRemaining': 0,
      'invoicesCount': 2,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePurchasesRepository implements PurchasesRepository {
  final List<PurchaseInvoice> allInvoices = [
    PurchaseInvoice(
      id: 1,
      invoiceNumber: 'PUR-001',
      supplierId: 1,
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 500,
      total: 500,
      paidAmount: 500,
      remainingAmount: 0,
      paymentType: PurchasePaymentType.cash,
      status: PurchaseInvoiceStatus.completed,
      supplierName: 'أنور',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    PurchaseInvoice(
      id: 2,
      invoiceNumber: 'PUR-002',
      supplierId: 2,
      invoiceDate: DateTime(2026, 1, 1),
      subtotal: 800,
      total: 800,
      paidAmount: 800,
      remainingAmount: 0,
      paymentType: PurchasePaymentType.cash,
      status: PurchaseInvoiceStatus.completed,
      supplierName: 'سامي',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<PurchaseInvoice>> getInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    PurchasePaymentType? paymentType,
    PurchaseInvoiceStatus? status,
    String? searchQuery,
  }) async {
    return allInvoices.where((inv) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return inv.invoiceNumber.contains(searchQuery) ||
            (inv.supplierName?.contains(searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Instant Search Tests (البحث الفوري من أول حرف في جميع الشاشات)', () {
    testWidgets('شاشة العملاء تتفاعل فوراً من أول حرف بدون الضغط على إنتر', (tester) async {
      final fakeRepo = FakeCustomersRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: CustomersListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      // كلا العميلين يظهران في البداية
      expect(find.text('أحمد علي'), findsOneWidget);
      expect(find.text('باسل محمود'), findsOneWidget);

      // إدخال حرف "أ" فقط في حقل البحث
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'أ');
      await tester.pumpAndSettle();

      // يجب أن يظهر فقط "أحمد علي" ويختفي "باسل محمود" فوراً بدون إنتر
      expect(find.text('أحمد علي'), findsOneWidget);
      expect(find.text('باسل محمود'), findsNothing);

      // مسح البحث عن طريق أيقونة الإلغاء
      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      // يعود كلاهما فوراً
      expect(find.text('أحمد علي'), findsOneWidget);
      expect(find.text('باسل محمود'), findsOneWidget);
    });

    testWidgets('شاشة المنتجات تتفاعل فوراً من أول حرف بدون الضغط على إنتر', (tester) async {
      final fakeProductsRepo = FakeProductsRepository();
      final fakeCategoriesRepo = FakeCategoriesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ProductsListScreen(
            productsRepository: fakeProductsRepo,
            categoriesRepository: fakeCategoriesRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أريكة جلدية'), findsOneWidget);
      expect(find.text('طاولة طعام'), findsOneWidget);

      // إدخال حرف "أ" في حقل البحث
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'أ');
      await tester.pumpAndSettle();

      expect(find.text('أريكة جلدية'), findsOneWidget);
      expect(find.text('طاولة طعام'), findsNothing);

      // مسح البحث
      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      expect(find.text('أريكة جلدية'), findsOneWidget);
      expect(find.text('طاولة طعام'), findsOneWidget);
    });

    testWidgets('شاشة الموردين تتفاعل فوراً من أول حرف بدون الضغط على إنتر', (tester) async {
      final fakeRepo = FakeSuppliersRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SuppliersListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنور للتجارة'), findsOneWidget);
      expect(find.text('سامي خليل'), findsOneWidget);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'أ');
      await tester.pumpAndSettle();

      expect(find.text('أنور للتجارة'), findsOneWidget);
      expect(find.text('سامي خليل'), findsNothing);

      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      expect(find.text('أنور للتجارة'), findsOneWidget);
      expect(find.text('سامي خليل'), findsOneWidget);
    });

    testWidgets('شاشة فواتير المبيعات تتفاعل فوراً من أول حرف بدون إنتر', (tester) async {
      final fakeRepo = FakeSalesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SalesListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INV-001'), findsOneWidget);
      expect(find.text('INV-002'), findsOneWidget);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '001');
      await tester.pumpAndSettle();

      expect(find.text('INV-001'), findsOneWidget);
      expect(find.text('INV-002'), findsNothing);
    });

    testWidgets('شاشة فواتير الشراء تتفاعل فوراً من أول حرف بدون إنتر', (tester) async {
      final fakeRepo = FakePurchasesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: PurchasesListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PUR-001'), findsOneWidget);
      expect(find.text('PUR-002'), findsOneWidget);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '001');
      await tester.pumpAndSettle();

      expect(find.text('PUR-001'), findsOneWidget);
      expect(find.text('PUR-002'), findsNothing);
    });
  });
}
