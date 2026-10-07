import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../cash/data/repositories/cashbox_repository_impl.dart';
import '../../../cash/domain/repositories/cashbox_repository.dart';
import '../../data/repositories/expenses_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../dialogs/add_expense_dialog.dart';

/// شاشة إدارة وتسجيل المصروفات التشغيلية
class ExpensesScreen extends StatefulWidget {
  final ExpensesRepository? expensesRepository;
  final CashboxRepository? cashboxRepository;

  const ExpensesScreen({
    super.key,
    this.expensesRepository,
    this.cashboxRepository,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final CashboxRepository _cashboxRepo;
  late final ExpensesRepository _expensesRepo;

  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  int _todayTotal = 0;
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _cashboxRepo = widget.cashboxRepository ?? CashboxRepositoryImpl();
    _expensesRepo = widget.expensesRepository ??
        ExpensesRepositoryImpl(cashboxRepo: _cashboxRepo);
    _loadData();
    AppDataNotifier.instance.addListener(_onAppDataChanged);
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  void _onAppDataChanged() {
    final event = AppDataNotifier.instance.lastEvent;
    if (event == null ||
        event.type == AppDataChangeType.expenses ||
        event.type == AppDataChangeType.cashbox ||
        event.type == AppDataChangeType.all) {
      if (mounted) {
        _loadData(silent: true);
      }
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await _expensesRepo.getExpenses(
        category: _selectedCategoryFilter,
      );
      final cats = await _expensesRepo.getCategories();
      final today = await _expensesRepo.getTodayExpensesTotal();

      if (mounted) {
        setState(() {
          _expenses = items;
          _categories = cats;
          _todayTotal = today;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      final failure = ErrorHandler.handle(e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddExpenseDialog() async {
    final result = await AddExpenseDialog.show(
      context,
      expensesRepository: _expensesRepo,
      cashboxRepository: _cashboxRepo,
    );

    if (result != null) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل المصروف بقيمة ${Formatters.formatCurrency(result.amount)} وصرفه من الصندوق بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, size: 24),
            SizedBox(width: 10),
            Text('المصروفات التشغيلية'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],

                    // 1. بطاقة إجمالي مصروفات اليوم
                    _buildTodayExpenseSummaryCard(),
                    const SizedBox(height: 16),

                    // 2. زر إضافة مصروف جديد
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _openAddExpenseDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'تسجيل مصروف جديد',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. فلاتر التصنيفات
                    _buildCategoryFilterRow(),
                    const SizedBox(height: 16),

                    // 4. ترويسة القائمة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'سجل المصروفات المسجلة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${_expenses.length} مصروف',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. قائمة المصروفات
                    if (_expenses.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(_expenses[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodayExpenseSummaryCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: Colors.red.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_down, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي مصروفات اليوم',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'المصروفات النقدية المصروفة اليوم',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Text(
            Formatters.formatCurrency(_todayTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('جميع التصنيفات'),
            selected: _selectedCategoryFilter == null,
            onSelected: (val) {
              if (val) {
                setState(() => _selectedCategoryFilter = null);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 8),
          ..._categories.map((c) {
            final isSelected = _selectedCategoryFilter == c.name;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: isSelected,
                onSelected: (val) {
                  setState(() => _selectedCategoryFilter = val ? c.name : null);
                  _loadData();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.outbox, color: Colors.red.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.categoryName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        expense.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      Formatters.formatDateTime(expense.expenseDate),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '| ${expense.notes!}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '-${Formatters.formatCurrency(expense.amount)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.money_off, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا توجد مصروفات مسجلة مطابقة حتى الآن',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'يمكنك تسجيل مصاريف الكهرباء، الإيجار، النقل، أو أي مصاريف تشغيلية.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
