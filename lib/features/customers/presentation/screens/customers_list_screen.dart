import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../data/repositories/customers_repository_impl.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import 'add_edit_customer_dialog.dart';
import 'customer_details_screen.dart';

/// شاشة قائمة وسجل العملاء وإدارتهم
class CustomersListScreen extends StatefulWidget {
  final CustomersRepository? repository;

  const CustomersListScreen({super.key, this.repository});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  late final CustomersRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _onlyActive = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CustomersRepositoryImpl();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getCustomers(
        onlyActive: _onlyActive,
        searchQuery: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل بيانات العملاء';
          _isLoading = false;
        });
      }
    }
  }

  int get _totalDebt => _customers.fold(0, (sum, c) => sum + c.currentBalance);

  Future<void> _openAddCustomer() async {
    final created = await AddEditCustomerDialog.show(context, repository: _repository);
    if (created != null) {
      _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: _loadCustomers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: _openAddCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
      body: Column(
        children: [
          // 1. شريط إحصائي أعلى الشاشة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'إجمالي العملاء: ${_customers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إجمالي ديون العملاء: ${AppFormatters.currency(_totalDebt)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. شريط البحث والتصفية
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم العميل أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadCustomers();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _loadCustomers(),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('النشطين فقط'),
                  selected: _onlyActive,
                  onSelected: (val) {
                    setState(() => _onlyActive = val);
                    _loadCustomers();
                  },
                ),
              ],
            ),
          ),

          // 3. قائمة العملاء
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _customers.isEmpty
                        ? const Center(
                            child: Text(
                              'لا يوجد عملاء مطابقين للبحث',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _customers.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final customer = _customers[index];
                                final hasDebt = customer.currentBalance > 0;

                                return Card(
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: hasDebt
                                          ? AppColors.error.withAlpha(80)
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: hasDebt
                                          ? AppColors.errorContainer
                                          : AppColors.primaryContainer,
                                      child: Icon(
                                        customer.isWalkInGeneralCustomer
                                            ? Icons.storefront
                                            : Icons.person,
                                        color: hasDebt ? AppColors.error : AppColors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      customer.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: customer.isActive
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    subtitle: Text(
                                      customer.phone != null && customer.phone!.isNotEmpty
                                          ? customer.phone!
                                          : (customer.notes ?? 'لا توجد ملاحظات'),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(customer.currentBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: hasDebt ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                        Text(
                                          hasDebt ? 'مستحق للمحل' : 'لا توجد ديون',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDebt ? AppColors.error : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CustomerDetailsScreen(
                                            customerId: customer.id,
                                            repository: _repository,
                                          ),
                                        ),
                                      );
                                      _loadCustomers();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
