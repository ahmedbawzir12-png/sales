import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/data/constants/database_constants.dart';
import '../../../../core/data/database/database_service.dart';
import '../../../../core/domain/errors/exceptions.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import '../models/customer_model.dart';

/// تطبيق مستودع العملاء باستخدام SQLite
class CustomersRepositoryImpl implements CustomersRepository {
  final DatabaseService _dbService;

  CustomersRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<Customer>> getCustomers({bool? onlyActive, String? searchQuery}) async {
    try {
      final db = await _dbService.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (onlyActive == true) {
        whereClauses.add('c.is_active = 1');
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        whereClauses.add('(c.name LIKE ? OR c.phone LIKE ? OR c.notes LIKE ?)');
        whereArgs.addAll([term, term, term]);
      }

      final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      // استعلام تجميعي يدمج رصيد الديون المستحقة الفعلي من فواتير المبيعات الآجلة المكتملة
      final sql = '''
        SELECT 
          c.*,
          COALESCE(SUM(CASE WHEN s.payment_type = 'credit' AND s.status = 'completed' THEN s.remaining_amount ELSE 0 END), 0) AS calculated_debt
        FROM ${DatabaseConstants.tableCustomers} c
        LEFT JOIN ${DatabaseConstants.tableSalesInvoices} s ON c.id = s.customer_id
        $whereString
        GROUP BY c.id
        ORDER BY c.id ASC
      ''';

      final results = await db.rawQuery(sql, whereArgs);

      return results.map((row) {
        final debt = (row['calculated_debt'] as num?)?.toInt() ?? 0;
        final base = CustomerModel.fromMap(row).toEntity();
        return base.copyWith(currentBalance: debt);
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع قائمة العملاء من قاعدة البيانات', e);
    }
  }

  @override
  Future<Customer> getCustomerById(int id) async {
    try {
      final db = await _dbService.database;

      final sql = '''
        SELECT 
          c.*,
          COALESCE(SUM(CASE WHEN s.payment_type = 'credit' AND s.status = 'completed' THEN s.remaining_amount ELSE 0 END), 0) AS calculated_debt
        FROM ${DatabaseConstants.tableCustomers} c
        LEFT JOIN ${DatabaseConstants.tableSalesInvoices} s ON c.id = s.customer_id
        WHERE c.id = ?
        GROUP BY c.id
        LIMIT 1
      ''';

      final results = await db.rawQuery(sql, [id]);

      if (results.isEmpty) {
        throw NotFoundException('العميل المطلوب برقم ($id) غير موجود');
      }

      final row = results.first;
      final debt = (row['calculated_debt'] as num?)?.toInt() ?? 0;
      return CustomerModel.fromMap(row).toEntity().copyWith(currentBalance: debt);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع بيانات العميل رقم ($id)', e);
    }
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final trimmedName = customer.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم العميل مطلوب ولا يمكن تركه فارغاً');
    }

    try {
      final db = await _dbService.database;

      // فحص عدم تكرار الاسم
      final existing = await db.query(
        DatabaseConstants.tableCustomers,
        where: 'name = ?',
        whereArgs: [trimmedName],
      );

      if (existing.isNotEmpty) {
        throw ValidationException('يوجد عميل مسجل مسبقاً بهذا الاسم ($trimmedName)');
      }

      final now = DateTime.now();
      final model = CustomerModel.fromEntity(
        customer.copyWith(
          name: trimmedName,
          createdAt: now,
          updatedAt: now,
        ),
      );

      return await db.insert(
        DatabaseConstants.tableCustomers,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل حفظ العميل في قاعدة البيانات', e);
    }
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final trimmedName = customer.name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('اسم العميل مطلوب ولا يمكن تركه فارغاً');
    }

    try {
      final db = await _dbService.database;

      // فحص عدم تكرار الاسم مع عميل آخر
      final existing = await db.query(
        DatabaseConstants.tableCustomers,
        where: 'name = ? AND id != ?',
        whereArgs: [trimmedName, customer.id],
      );

      if (existing.isNotEmpty) {
        throw ValidationException('يوجد عميل آخر مسجل بنفس الاسم ($trimmedName)');
      }

      final now = DateTime.now().toIso8601String();
      final count = await db.update(
        DatabaseConstants.tableCustomers,
        {
          'name': trimmedName,
          'phone': customer.phone?.trim(),
          'whatsapp': customer.whatsapp?.trim(),
          'address': customer.address?.trim(),
          'notes': customer.notes?.trim(),
          'is_active': customer.isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      if (count == 0) {
        throw NotFoundException('العميل المراد تعديله برقم (${customer.id}) غير موجود');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تعديل بيانات العميل رقم (${customer.id})', e);
    }
  }

  @override
  Future<void> toggleCustomerActive(int id, bool isActive) async {
    try {
      final db = await _dbService.database;
      final now = DateTime.now().toIso8601String();

      final count = await db.update(
        DatabaseConstants.tableCustomers,
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw NotFoundException('العميل برقم ($id) غير موجود لتعديل حالته');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل تحديث حالة نشاط العميل رقم ($id)', e);
    }
  }

  @override
  Future<int> getCustomerDebt(int customerId) async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(remaining_amount), 0) AS total_debt
        FROM ${DatabaseConstants.tableSalesInvoices}
        WHERE customer_id = ? AND payment_type = 'credit' AND status = 'completed'
      ''', [customerId]);

      return (result.first['total_debt'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل احتساب دين العميل رقم ($customerId)', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getCustomerStatistics(int customerId) async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) AS invoice_count,
          COALESCE(SUM(total), 0) AS total_sales,
          COALESCE(SUM(paid_amount), 0) AS total_paid,
          COALESCE(SUM(CASE WHEN payment_type = 'credit' THEN remaining_amount ELSE 0 END), 0) AS total_remaining
        FROM ${DatabaseConstants.tableSalesInvoices}
        WHERE customer_id = ? AND status = 'completed'
      ''', [customerId]);

      final row = result.first;
      return {
        'invoiceCount': (row['invoice_count'] as num?)?.toInt() ?? 0,
        'totalSales': (row['total_sales'] as num?)?.toInt() ?? 0,
        'totalPaid': (row['total_paid'] as num?)?.toInt() ?? 0,
        'totalRemaining': (row['total_remaining'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('فشل استرجاع إحصائيات مبيعات العميل رقم ($customerId)', e);
    }
  }
}
