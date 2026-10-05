import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../purchases/data/repositories/purchases_repository_impl.dart';
import '../../../purchases/domain/entities/purchase_invoice.dart';
import '../../../purchases/domain/repositories/purchases_repository.dart';
import '../../../purchases/presentation/screens/purchase_invoice_details_screen.dart';
import '../../data/repositories/supplier_ledger_repository_impl.dart';
import '../../data/repositories/supplier_payments_repository_impl.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_ledger_entry.dart';
import '../../domain/repositories/supplier_ledger_repository.dart';
import '../../domain/repositories/supplier_payments_repository.dart';
import '../../domain/repositories/suppliers_repository.dart';
import 'add_edit_supplier_dialog.dart';
import 'record_supplier_payment_dialog.dart';

/// شاشة تفاصيل المورد وسجل فواتيره ومستحقاته وكشف حسابه
class SupplierDetailsScreen extends StatefulWidget {
  final int supplierId;
  final SuppliersRepository suppliersRepository;
  final PurchasesRepository purchasesRepository;
  final SupplierPaymentsRepository paymentsRepository;
  final SupplierLedgerRepository ledgerRepository;

  SupplierDetailsScreen({
    super.key,
    required this.supplierId,
    required this.suppliersRepository,
    PurchasesRepository? purchasesRepository,
    SupplierPaymentsRepository? paymentsRepository,
    SupplierLedgerRepository? ledgerRepository,
  })  : purchasesRepository = purchasesRepository ?? PurchasesRepositoryImpl(),
        paymentsRepository = paymentsRepository ?? SupplierPaymentsRepositoryImpl(),
        ledgerRepository = ledgerRepository ?? SupplierLedgerRepositoryImpl();

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen>
    with SingleTickerProviderStateMixin {
  Supplier? _supplier;
  List<PurchaseInvoice> _invoices = [];
  List<SupplierLedgerEntry> _ledgerEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupplierData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supplier = await widget.suppliersRepository.getSupplierById(widget.supplierId);
      final invoices = await widget.purchasesRepository.getInvoices(supplierId: widget.supplierId);
      final ledger = await widget.ledgerRepository.getLedgerEntries(widget.supplierId);

      if (mounted) {
        setState(() {
          _supplier = supplier;
          _invoices = invoices;
          _ledgerEntries = ledger;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل بيانات المورد وفواتيره';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPayment() async {
    if (_supplier == null) return;
    if (_supplier!.currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مستحقات أو ديون مسجلة لهذا المورد لسدادها')),
      );
      return;
    }

    final payment = await RecordSupplierPaymentDialog.show(
      context,
      supplier: _supplier!,
      currentDebt: _supplier!.currentBalance,
      paymentsRepository: widget.paymentsRepository,
    );

    if (payment != null) {
      _loadSupplierData();
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

  Future<void> _editSupplier() async {
    if (_supplier == null) return;
    final updated = await AddEditSupplierDialog.show(
      context,
      repository: widget.suppliersRepository,
      supplierToEdit: _supplier,
    );
    if (updated != null) {
      _loadSupplierData();
    }
  }

  Future<void> _toggleActiveStatus() async {
    if (_supplier == null) return;
    final newStatus = !_supplier!.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus ? 'تفعيل المورد' : 'تعطيل المورد'),
        content: Text(
          newStatus
              ? 'هل ترغب في إعادة تفعيل المورد "${_supplier!.name}"؟'
              : 'هل ترغب في تعطيل المورد "${_supplier!.name}"؟ ستبقى سجلاته التاريخية وفواتيره محفوظة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(newStatus ? 'تفعيل' : 'تعطيل'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.suppliersRepository.setSupplierActive(_supplier!.id, newStatus);
        _loadSupplierData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'تم تفعيل المورد بنجاح' : 'تم تعطيل المورد بنجاح'),
              backgroundColor: newStatus ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل تحديث حالة المورد: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المورد')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _supplier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'المورد غير موجود'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadSupplierData, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    final supplier = _supplier!;
    final totalPurchases = _invoices.fold<int>(0, (sum, inv) => sum + inv.total);
    final totalPaid = _invoices.fold<int>(0, (sum, inv) => sum + inv.paidAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        actions: [
          ElevatedButton.icon(
            onPressed: supplier.currentBalance > 0 ? _recordPayment : null,
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
            onPressed: _editSupplier,
          ),
          IconButton(
            icon: Icon(supplier.isActive ? Icons.block : Icons.check_circle_outline),
            tooltip: supplier.isActive ? 'تعطيل المورد' : 'تفعيل المورد',
            onPressed: _toggleActiveStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSupplierData,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. بطاقة معلومات المورد
                    _buildSupplierProfileCard(supplier),
                    const SizedBox(height: 16),

                    // 2. إحصائيات الديون والمشتريات
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'الرصيد المستحق (دين)',
                            value: Formatters.formatCurrency(supplier.currentBalance),
                            icon: Icons.account_balance_wallet_outlined,
                            color: supplier.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'إجمالي المشتريات',
                            value: Formatters.formatCurrency(totalPurchases),
                            icon: Icons.shopping_cart_outlined,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'المبالغ المدفوعة',
                            value: Formatters.formatCurrency(totalPaid),
                            icon: Icons.payments_outlined,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
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
                      text: 'فواتير الشراء (${_invoices.length})',
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

  Widget _buildSupplierProfileCard(Supplier supplier) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.business,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
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
                              color: supplier.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: supplier.isActive ? Colors.green.shade300 : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              supplier.isActive ? 'مورد نشط' : 'مورد معطل',
                              style: TextStyle(
                                color: supplier.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (supplier.phone != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              supplier.phone!,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (supplier.address != null && supplier.address!.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(supplier.address!)),
                ],
              ),
            ],
            if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      supplier.notes!,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTab() {
    if (_ledgerEntries.isEmpty) {
      return const Center(
        child: Text('لا توجد حركات مالية مسجلة في كشف حساب هذا المورد'),
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
        child: Text('لا توجد فواتير شراء مسجلة لهذا المورد'),
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
                  builder: (context) => PurchaseInvoiceDetailsScreen(
                    invoiceId: invoice.id,
                    purchasesRepository: widget.purchasesRepository,
                  ),
                ),
              );
              _loadSupplierData();
            },
            leading: CircleAvatar(
              backgroundColor: invoice.isCredit ? Colors.orange.shade50 : Colors.green.shade50,
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
                  Formatters.formatCurrency(invoice.total),
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

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
                fontSize: 16,
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
