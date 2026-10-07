import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_card.dart';
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
    if (event.type == AppDataChangeType.sales ||
        event.type == AppDataChangeType.all ||
        (event.type == AppDataChangeType.tabSelection && event.payload == 1)) {
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
      final list = await _repository.getInvoices(
        paymentType: _selectedPaymentType,
        status: _selectedStatus,
        searchQuery: _searchController.text.trim(),
      );
      final metrics = await _repository.getSalesSummaryMetrics();

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _invoices = list;
          _metrics = metrics;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      final failure = ErrorHandler.handle(e, s);
      if (mounted && currentSeq == _searchSequence) {
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
          // 1. شريط المؤشرات المالية للمبيعات — متجاوب وسلس بـ IntrinsicHeight بدون أبعاد ثابتة
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // تم استخدام Expanded لتقسيم المؤشرات بالتساوي وضمان التجاوب
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('إجمالي المبيعات', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(_metrics['totalSales'] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('المقبوض نقداً', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(_metrics['totalPaid'] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('الآجل المتبقي', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(_metrics['totalRemaining'] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.error),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

                                // تم استبدال Card بـ AppCard المتجاوب مع مسافة 16px وحواف ناعمة 14px بدون أي أبعاد ثابتة
                                return AppCard(
                                  padding: const EdgeInsets.all(16), // مسافة داخلية مريحة لا تقل عن 16px
                                  backgroundColor: isCancelled ? AppColors.surfaceElevated : AppColors.surface,
                                  borderColor: isCancelled
                                      ? AppColors.borderStrong
                                      : (isCredit && invoice.remainingAmount > 0
                                          ? AppColors.warning.withAlpha(90)
                                          : AppColors.border),
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
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // أيقونة نوع الفاتورة بحجم متناسب
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isCancelled
                                              ? AppColors.surfaceHighlight
                                              : (isCredit ? AppColors.warningContainer : AppColors.primaryContainer),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCancelled
                                              ? Icons.cancel_outlined
                                              : (isCredit ? Icons.access_time : Icons.payments_outlined),
                                          color: isCancelled
                                              ? AppColors.textMuted
                                              : (isCredit ? AppColors.warning : AppColors.primary),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // تفاصيل الفاتورة — تم استخدام Expanded لمنع أي تجاوز نصوص على الشاشات الصغيرة
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    invoice.invoiceNumber,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                      color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isCancelled
                                                        ? AppColors.errorContainer
                                                        : (isCredit ? AppColors.warningContainer : AppColors.successContainer),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    invoice.status.arabicLabel,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isCancelled
                                                          ? AppColors.error
                                                          : (isCredit ? AppColors.warning : AppColors.success),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${invoice.customerName ?? "زبون عام"} • ${AppFormatters.date(invoice.invoiceDate)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isCancelled ? AppColors.textMuted : AppColors.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // المبالغ المالية مع تمييز الديون والمدفوع
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            AppFormatters.currency(invoice.totalAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                              color: isCancelled ? AppColors.textMuted : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          if (isCredit && invoice.remainingAmount > 0)
                                            Text(
                                              'متبقي: ${AppFormatters.currency(invoice.remainingAmount)}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                                            )
                                          else
                                            Text(
                                              isCancelled ? 'ملغاة' : 'مسددة بالكامل',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isCancelled ? AppColors.textMuted : AppColors.success,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
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
