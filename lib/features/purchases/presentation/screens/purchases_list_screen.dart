import 'package:flutter/material.dart';
import 'package:sales/core/presentation/services/app_data_notifier.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import '../../data/repositories/purchases_repository_impl.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_status.dart';
import '../../domain/entities/purchase_payment_type.dart';
import '../../domain/repositories/purchases_repository.dart';
import 'new_purchase_invoice_screen.dart';
import 'purchase_invoice_details_screen.dart';

/// شاشة قائمة فواتير الشراء مع البحث والتصفية وعرض الملخص
class PurchasesListScreen extends StatefulWidget {
  final PurchasesRepository repository;

  PurchasesListScreen({
    super.key,
    PurchasesRepository? repository,
  }) : repository = repository ?? PurchasesRepositoryImpl();

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseInvoice> _invoices = [];
  PurchasePaymentType? _selectedPaymentType;
  PurchaseInvoiceStatus? _selectedStatus;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppDataNotifier.instance.addListener(_onAppDataChanged);
    _loadInvoices();
  }

  @override
  void dispose() {
    AppDataNotifier.instance.removeListener(_onAppDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAppDataChanged() {
    final event = AppDataNotifier.instance.lastEvent;
    if (event == null) return;
    if (event.type == AppDataChangeType.purchases ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 2)) {
      if (mounted) {
        _loadInvoices(isSilent: true);
      }
    }
  }

  int _searchSequence = 0;

  Future<void> _loadInvoices({bool isSilent = false}) async {
    final currentSeq = ++_searchSequence;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final invoices = await widget.repository.getInvoices(
        searchQuery: _searchController.text.trim(),
        paymentType: _selectedPaymentType,
        status: _selectedStatus,
      );

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _errorMessage = 'فشل تحميل قائمة فواتير الشراء';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openNewInvoice() async {
    final result = await Navigator.of(context).push<PurchaseInvoice>(
      MaterialPageRoute(
        builder: (_) => NewPurchaseInvoiceScreen(
          purchasesRepository: widget.repository,
        ),
      ),
    );

    if (result != null) {
      _loadInvoices();
    }
  }

  int get _totalCompletedAmount {
    return _invoices
        .where((inv) => !inv.isCancelled)
        .fold<int>(0, (sum, inv) => sum + inv.total);
  }

  int get _totalRemainingDebt {
    return _invoices
        .where((inv) => !inv.isCancelled)
        .fold<int>(0, (sum, inv) => sum + inv.remainingAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فواتير المشتريات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadInvoices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'purchases_fab',
        onPressed: _openNewInvoice,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('فاتورة شراء جديدة'),
      ),
      body: Column(
        children: [
          // 1. شريط ملخص إجمالي المشتريات والديون
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي المشتريات (النشطة)',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      Text(
                        AppFormatters.currency(_totalCompletedAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'المتبقي غير المسدد (ديون)',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      Text(
                        AppFormatters.currency(_totalRemainingDebt),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _totalRemainingDebt > 0 ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. أدوات البحث والتصفية
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الفاتورة أو اسم المورد...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _loadInvoices(isSilent: true);
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _loadInvoices(isSilent: true);
                  },
                  onSubmitted: (_) => _loadInvoices(isSilent: true),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('الكل'),
                        selected: _selectedPaymentType == null && _selectedStatus == null,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedPaymentType = null;
                              _selectedStatus = null;
                            });
                            _loadInvoices();
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('نقداً'),
                        selected: _selectedPaymentType == PurchasePaymentType.cash,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? PurchasePaymentType.cash : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('آجل'),
                        selected: _selectedPaymentType == PurchasePaymentType.credit,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? PurchasePaymentType.credit : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('ملغاة'),
                        selected: _selectedStatus == PurchaseInvoiceStatus.cancelled,
                        onSelected: (val) {
                          setState(() => _selectedStatus = val ? PurchaseInvoiceStatus.cancelled : null);
                          _loadInvoices();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. قائمة الفواتير
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadInvoices,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _invoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد فواتير شراء مسجلة',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadInvoices,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _invoices.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                return Card(
                                  elevation: 1,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: invoice.isCancelled
                                          ? Colors.red.shade50
                                          : invoice.isPaidInFull
                                              ? Colors.green.shade50
                                              : Colors.orange.shade50,
                                      child: Icon(
                                        invoice.isCancelled
                                            ? Icons.close
                                            : invoice.isPaidInFull
                                                ? Icons.check
                                                : Icons.access_time,
                                        color: invoice.isCancelled
                                            ? Colors.red
                                            : invoice.isPaidInFull
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          invoice.invoiceNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            decoration: invoice.isCancelled
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            invoice.paymentType.arabicLabel,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'المورد: ${invoice.supplierName ?? "غير محدد"}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          'التاريخ: ${AppFormatters.date(invoice.invoiceDate)}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(invoice.total),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: invoice.isCancelled
                                                ? Colors.grey
                                                : Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          invoice.isCancelled
                                              ? 'ملغاة'
                                              : invoice.isPaidInFull
                                                  ? 'مسددة بالكامل'
                                                  : 'متبقي: ${AppFormatters.currency(invoice.remainingAmount)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: invoice.isCancelled
                                                ? Colors.red
                                                : invoice.isPaidInFull
                                                    ? Colors.green
                                                    : Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PurchaseInvoiceDetailsScreen(
                                            invoiceId: invoice.id,
                                            purchasesRepository: widget.repository,
                                          ),
                                        ),
                                      );
                                      _loadInvoices();
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
