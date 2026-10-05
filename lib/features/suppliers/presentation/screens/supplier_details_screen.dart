import 'package:flutter/material.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import 'package:sales/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:sales/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:sales/features/purchases/domain/repositories/purchases_repository.dart';
import 'package:sales/features/purchases/presentation/screens/purchase_invoice_details_screen.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/suppliers_repository.dart';
import 'add_edit_supplier_dialog.dart';

/// شاشة تفاصيل المورد وسجل فواتيره ومستحقاته
class SupplierDetailsScreen extends StatefulWidget {
  final int supplierId;
  final SuppliersRepository suppliersRepository;
  final PurchasesRepository purchasesRepository;

  SupplierDetailsScreen({
    super.key,
    required this.supplierId,
    required this.suppliersRepository,
    PurchasesRepository? purchasesRepository,
  }) : purchasesRepository = purchasesRepository ?? PurchasesRepositoryImpl();

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  Supplier? _supplier;
  List<PurchaseInvoice> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
  }

  Future<void> _loadSupplierData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supplier = await widget.suppliersRepository.getSupplierById(widget.supplierId);
      final invoices = await widget.purchasesRepository.getInvoices(supplierId: widget.supplierId);

      if (mounted) {
        setState(() {
          _supplier = supplier;
          _invoices = invoices;
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
      await widget.suppliersRepository.setSupplierActive(_supplier!.id, newStatus);
      _loadSupplierData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _supplier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المورد')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'المورد غير متوفر'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSupplierData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final supplier = _supplier!;
    final totalPurchases = _invoices.fold<int>(0, (sum, inv) => sum + (inv.isCancelled ? 0 : inv.total));
    final totalPaid = _invoices.fold<int>(0, (sum, inv) => sum + (inv.isCancelled ? 0 : inv.paidAmount));

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل بيانات المورد',
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة معلومات المورد
              Card(
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
                                        color: supplier.isActive
                                            ? Colors.green.shade50
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: supplier.isActive
                                              ? Colors.green.shade300
                                              : Colors.grey.shade400,
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
              ),

              const SizedBox(height: 16),

              // 2. إحصائيات الديون والمشتريات
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'إجمالي المشتريات',
                      value: AppFormatters.currency(totalPurchases),
                      icon: Icons.shopping_cart_outlined,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'المبالغ المدفوعة',
                      value: AppFormatters.currency(totalPaid),
                      icon: Icons.payments_outlined,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'الرصيد المستحق (دين)',
                      value: AppFormatters.currency(supplier.currentBalance),
                      icon: Icons.account_balance_wallet_outlined,
                      color: supplier.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. سجل فواتير الشراء للمورد
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'فواتير الشراء (${_invoices.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_invoices.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'لا توجد فواتير شراء مسجلة لهذا المورد حتى الآن',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _invoices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: inv.isCancelled
                              ? Colors.red.shade50
                              : inv.isPaidInFull
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          child: Icon(
                            inv.isCancelled
                                ? Icons.cancel_outlined
                                : inv.isPaidInFull
                                    ? Icons.check
                                    : Icons.hourglass_top,
                            color: inv.isCancelled
                                ? Colors.red
                                : inv.isPaidInFull
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              inv.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inv.paymentType.arabicLabel,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'التاريخ: ${AppFormatters.date(inv.invoiceDate)} | المتبقي: ${AppFormatters.currency(inv.remainingAmount)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(inv.total),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              inv.status.arabicLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: inv.isCancelled ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PurchaseInvoiceDetailsScreen(
                                invoiceId: inv.id,
                                purchasesRepository: widget.purchasesRepository,
                              ),
                            ),
                          );
                          _loadSupplierData();
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
