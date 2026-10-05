import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_invoice_status.dart';
import '../../domain/entities/sales_payment_type.dart';
import '../../domain/repositories/sales_repository.dart';
import 'pos_screen.dart';
import 'sales_invoice_details_screen.dart';

/// شاشة قائمة وسجل فواتير المبيعات
class SalesListScreen extends StatefulWidget {
  final SalesRepository? repository;

  const SalesListScreen({super.key, this.repository});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  late final SalesRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<SalesInvoice> _invoices = [];
  Map<String, dynamic> _metrics = {};
  bool _isLoading = true;
  String? _errorMessage;

  // فلاتر التصفية
  SalesPaymentType? _selectedPaymentType;
  SalesInvoiceStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SalesRepositoryImpl();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getInvoices(
        paymentType: _selectedPaymentType,
        status: _selectedStatus,
        searchQuery: _searchController.text.trim(),
      );
      final metrics = await _repository.getSalesSummaryMetrics();

      if (mounted) {
        setState(() {
          _invoices = list;
          _metrics = metrics;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted) {
        setState(() {
          _errorMessage = failure.userFriendlyMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openNewSale() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PosScreen()),
    );
    _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل فواتير المبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: _loadInvoices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_fab',
        onPressed: _openNewSale,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('عملية بيع جديدة'),
      ),
      body: Column(
        children: [
          // 1. شريط المؤشرات المالية للمبيعات
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المبيعات', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(
                        AppFormatters.currency(_metrics['totalSales'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المقبوض نقداً', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(
                        AppFormatters.currency(_metrics['totalPaid'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الآجل المتبقي (ديون)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(
                        AppFormatters.currency(_metrics['totalRemaining'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. شريط البحث والفلاتر
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الفاتورة، اسم العميل، أو الملاحظات...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadInvoices();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _loadInvoices(),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('الكل'),
                        selected: _selectedPaymentType == null && _selectedStatus == null,
                        onSelected: (_) {
                          setState(() {
                            _selectedPaymentType = null;
                            _selectedStatus = null;
                          });
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('نقدي فقط'),
                        selected: _selectedPaymentType == SalesPaymentType.cash,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? SalesPaymentType.cash : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('آجل فقط'),
                        selected: _selectedPaymentType == SalesPaymentType.credit,
                        onSelected: (val) {
                          setState(() => _selectedPaymentType = val ? SalesPaymentType.credit : null);
                          _loadInvoices();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('ملغاة فقط'),
                        selected: _selectedStatus == SalesInvoiceStatus.cancelled,
                        onSelected: (val) {
                          setState(() => _selectedStatus = val ? SalesInvoiceStatus.cancelled : null);
                          _loadInvoices();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. جدول وقائمة الفواتير
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _invoices.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد فواتير مبيعات مطابقة لمعايير البحث',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadInvoices,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              itemCount: _invoices.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                final isCredit = invoice.paymentType == SalesPaymentType.credit;
                                final isCancelled = invoice.isCancelled;

                                return Card(
                                  elevation: 0.5,
                                  color: isCancelled ? Colors.grey.shade50 : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isCancelled
                                          ? Colors.grey.shade300
                                          : (isCredit && invoice.remainingAmount > 0
                                              ? AppColors.warning.withAlpha(80)
                                              : AppColors.border),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCancelled
                                          ? Colors.grey.shade200
                                          : (isCredit ? AppColors.warningContainer : AppColors.primaryContainer),
                                      child: Icon(
                                        isCancelled
                                            ? Icons.cancel_outlined
                                            : (isCredit ? Icons.access_time : Icons.payments_outlined),
                                        color: isCancelled
                                            ? Colors.grey
                                            : (isCredit ? AppColors.warning : AppColors.primary),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          invoice.invoiceNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            color: isCancelled ? Colors.grey : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isCancelled
                                                ? AppColors.errorContainer
                                                : (isCredit ? AppColors.warningContainer : AppColors.successContainer),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            invoice.status.arabicLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isCancelled
                                                  ? AppColors.error
                                                  : (isCredit ? AppColors.warning : AppColors.success),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${invoice.customerName ?? "زبون عام"} • ${AppFormatters.date(invoice.invoiceDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCancelled ? Colors.grey : AppColors.textSecondary,
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(invoice.totalAmount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            color: isCancelled ? Colors.grey : AppColors.primary,
                                          ),
                                        ),
                                        if (isCredit && invoice.remainingAmount > 0)
                                          Text(
                                            'متبقي: ${AppFormatters.currency(invoice.remainingAmount)}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold),
                                          )
                                        else
                                          Text(
                                            isCancelled ? 'ملغاة' : 'مسددة بالكامل',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isCancelled ? Colors.grey : AppColors.success,
                                            ),
                                          ),
                                      ],
                                    ),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SalesInvoiceDetailsScreen(
                                            invoiceId: invoice.id,
                                            repository: _repository,
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
