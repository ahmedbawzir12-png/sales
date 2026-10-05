import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../sales/data/repositories/sales_repository_impl.dart';
import '../../../sales/domain/entities/sales_invoice.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../../sales/presentation/screens/sales_invoice_details_screen.dart';
import '../../data/repositories/customer_ledger_repository_impl.dart';
import '../../data/repositories/customer_payments_repository_impl.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger_entry.dart';
import '../../domain/repositories/customer_ledger_repository.dart';
import '../../domain/repositories/customer_payments_repository.dart';
import '../../domain/repositories/customers_repository.dart';
import 'add_edit_customer_dialog.dart';
import 'record_customer_payment_dialog.dart';

/// شاشة تفاصيل العميل وإحصائيات مبيعاته وكشف حسابه والديون المستحقة
class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;
  final CustomersRepository repository;
  final CustomerPaymentsRepository paymentsRepository;
  final CustomerLedgerRepository ledgerRepository;
  final SalesRepository salesRepository;

  CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.repository,
    CustomerPaymentsRepository? paymentsRepository,
    CustomerLedgerRepository? ledgerRepository,
    SalesRepository? salesRepository,
  })  : paymentsRepository = paymentsRepository ?? CustomerPaymentsRepositoryImpl(),
        ledgerRepository = ledgerRepository ?? CustomerLedgerRepositoryImpl(),
        salesRepository = salesRepository ?? SalesRepositoryImpl();

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  Customer? _customer;
  Map<String, dynamic>? _stats;
  List<CustomerLedgerEntry> _ledgerEntries = [];
  List<SalesInvoice> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomerDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customer = await widget.repository.getCustomerById(widget.customerId);
      final stats = await widget.repository.getCustomerStatistics(widget.customerId);
      final ledger = await widget.ledgerRepository.getLedgerEntries(widget.customerId);
      final invoices = await widget.salesRepository.getInvoices(customerId: widget.customerId);

      if (mounted) {
        setState(() {
          _customer = customer;
          _stats = stats;
          _ledgerEntries = ledger;
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل بيانات العميل';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPayment() async {
    if (_customer == null) return;
    if (_customer!.currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد ديون مستحقة على هذا العميل لسدادها')),
      );
      return;
    }

    final payment = await RecordCustomerPaymentDialog.show(
      context,
      customer: _customer!,
      currentDebt: _customer!.currentBalance,
      paymentsRepository: widget.paymentsRepository,
    );

    if (payment != null) {
      _loadCustomerDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم تسجيل الدفعة بنجاح بمبلغ ${Formatters.formatCurrency(payment.amount)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _editCustomer() async {
    if (_customer == null) return;
    final updated = await AddEditCustomerDialog.show(
      context,
      repository: widget.repository,
      customerToEdit: _customer,
    );
    if (updated != null) {
      _loadCustomerDetails();
    }
  }

  Future<void> _toggleStatus() async {
    if (_customer == null) return;
    final newStatus = !_customer!.isActive;
    final actionText = newStatus ? 'تنشيط' : 'تعطيل';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionText العميل'),
        content: Text('هل أنت متأكد من رغبتك في $actionText حساب العميل "${_customer!.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.toggleCustomerActive(_customer!.id, newStatus);
        _loadCustomerDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم $actionText العميل بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل تغيير حالة العميل')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'تفاصيل العميل'),
        actions: [
          if (_customer != null) ...[
            ElevatedButton.icon(
              onPressed: _customer!.currentBalance > 0 ? _recordPayment : null,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('تسجيل دفعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل البيانات',
              onPressed: _editCustomer,
            ),
            IconButton(
              icon: Icon(_customer!.isActive ? Icons.block : Icons.check_circle_outline),
              tooltip: _customer!.isActive ? 'تعطيل العميل' : 'تنشيط العميل',
              onPressed: _toggleStatus,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _customer == null
                  ? const Center(child: Text('العميل غير موجود'))
                  : RefreshIndicator(
                      onRefresh: _loadCustomerDetails,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. بطاقة معلومات العميل
                                  _buildCustomerProfileCard(),
                                  const SizedBox(height: 16),

                                  // 2. بطاقات المؤشرات المالية
                                  _buildFinancialSummaryCards(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverAppBarDelegate(
                              TabBar(
                                controller: _tabController,
                                labelColor: AppColors.primary,
                                unselectedLabelColor: Colors.grey.shade600,
                                indicatorColor: AppColors.primary,
                                indicatorWeight: 3,
                                tabs: [
                                  Tab(
                                    icon: const Icon(Icons.account_balance_wallet_outlined),
                                    text: 'كشف الحساب وسجل الحركات (${_ledgerEntries.length})',
                                  ),
                                  Tab(
                                    icon: const Icon(Icons.receipt_long_outlined),
                                    text: 'فواتير المبيعات (${_invoices.length})',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        body: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLedgerTab(),
                            _buildInvoicesTab(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildCustomerProfileCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryContainer,
                  child: const Icon(Icons.person, size: 32, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer!.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _customer!.isActive
                                  ? AppColors.successContainer
                                  : AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _customer!.isActive ? 'عميل نشط' : 'عميل معطل',
                              style: TextStyle(
                                color: _customer!.isActive ? AppColors.success : AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_customer!.phone != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(_customer!.phone!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_customer!.address != null && _customer!.address!.isNotEmpty) ...[
              const Divider(height: 20),
              _buildInfoRow(Icons.location_on_outlined, 'العنوان', _customer!.address!),
            ],
            if (_customer!.notes != null && _customer!.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(Icons.notes, 'ملاحظات', _customer!.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'رصيد الدين المستحق',
                value: Formatters.formatCurrency(_customer!.currentBalance),
                color: _customer!.currentBalance > 0 ? AppColors.error : AppColors.success,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي المبيعات',
                value: Formatters.formatCurrency(_stats?['totalSales'] ?? 0),
                color: AppColors.primary,
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي المقبوضات',
                value: Formatters.formatCurrency(_stats?['totalPaid'] ?? 0),
                color: AppColors.success,
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerTab() {
    if (_ledgerEntries.isEmpty) {
      return const Center(
        child: Text('لا توجد حركات مالية مسجلة في كشف حساب هذا العميل'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _ledgerEntries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _ledgerEntries[index];
        final isDebit = entry.transactionType.isDebtIncrease;

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDebit
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDebit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: isDebit ? AppColors.error : AppColors.success,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.transactionType.arabicLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${isDebit ? "+" : "-"}${Formatters.formatCurrency(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDebit ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${Formatters.formatDate(entry.transactionDate)} | ${entry.notes ?? ""}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) {
      return const Center(
        child: Text('لا توجد فواتير مبيعات مسجلة لهذا العميل'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return Card(
          elevation: 1,
          child: ListTile(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SalesInvoiceDetailsScreen(
                    invoiceId: invoice.id,
                    repository: widget.salesRepository,
                  ),
                ),
              );
              _loadCustomerDetails();
            },
            leading: CircleAvatar(
              backgroundColor: invoice.isCredit
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              child: Icon(
                invoice.isCredit ? Icons.credit_card : Icons.money,
                color: invoice.isCredit ? Colors.orange.shade800 : Colors.green.shade800,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  Formatters.formatCurrency(invoice.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${Formatters.formatDate(invoice.invoiceDate)} | ${invoice.paymentType.arabicLabel}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  invoice.isPaid
                      ? 'مدفوعة بالكامل'
                      : 'متبقي: ${Formatters.formatCurrency(invoice.remainingAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: invoice.isPaid ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
