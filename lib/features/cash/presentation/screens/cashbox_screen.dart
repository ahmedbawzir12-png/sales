import 'package:flutter/material.dart';
import '../../../../core/domain/errors/error_handler.dart';
import '../../../../core/presentation/services/app_data_notifier.dart';
import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/utils/formatters.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../data/repositories/cashbox_repository_impl.dart';
import '../../domain/entities/cash_flow_direction.dart';
import '../../domain/entities/cash_transaction.dart';
import '../../domain/entities/cashbox_summary.dart';
import '../../domain/repositories/cashbox_repository.dart';
import '../dialogs/cash_transaction_details_dialog.dart';
import '../dialogs/record_other_deposit_dialog.dart';
import '../dialogs/record_owner_withdrawal_dialog.dart';
import '../dialogs/set_opening_balance_dialog.dart';

/// شاشة الصندوق المالي وحركات النقدية (Cashbox / Cash Register)
class CashboxScreen extends StatefulWidget {
  final CashboxRepository? repository;

  const CashboxScreen({super.key, this.repository});

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  late final CashboxRepository _repository;

  CashboxSummary? _summary;
  List<CashTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  CashFlowDirection? _selectedDirectionFilter;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CashboxRepositoryImpl();
    _loadCashboxData();
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
        event.type == AppDataChangeType.cashbox ||
        event.type == AppDataChangeType.sales ||
        event.type == AppDataChangeType.purchases ||
        event.type == AppDataChangeType.customers ||
        event.type == AppDataChangeType.suppliers ||
        event.type == AppDataChangeType.expenses ||
        event.type == AppDataChangeType.all) {
      if (mounted) {
        _loadCashboxData(silent: true);
      }
    }
  }

  Future<void> _loadCashboxData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final summary = await _repository.getCashboxSummary();
      final txs = await _repository.getTransactions(
        direction: _selectedDirectionFilter,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _transactions = txs;
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

  Future<void> _onSetOpeningBalance() async {
    final result = await SetOpeningBalanceDialog.show(
      context,
      repository: _repository,
    );
    if (result != null) {
      _loadCashboxData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الرصيد الافتتاحي للصندوق بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _onRecordOwnerWithdrawal() async {
    final currentBal = _summary?.currentBalance ?? 0;
    if (currentBal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إجراء سحب، رصيد الصندوق الحالي صفر أو غير كافٍ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final result = await RecordOwnerWithdrawalDialog.show(
      context,
      repository: _repository,
      currentBalance: currentBal,
    );

    if (result != null) {
      _loadCashboxData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل سحب نقدي لصاحب المحل بمبلغ ${Formatters.formatCurrency(result.amount)} بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _onRecordOtherDeposit() async {
    final result = await RecordOtherDepositDialog.show(
      context,
      repository: _repository,
    );

    if (result != null) {
      _loadCashboxData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل إيداع نقدي إضافي بمبلغ ${Formatters.formatCurrency(result.amount)} بنجاح',
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
            Icon(Icons.point_of_sale, size: 24),
            SizedBox(width: 10),
            Text('صندوق النقدية العام'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الحسابات',
            onPressed: () => _loadCashboxData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadCashboxData(),
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

                    // 1. بطاقة الرصيد الفعلي الحالي (Hero Balance Card)
                    _buildBalanceHeroCard(),
                    const SizedBox(height: 16),

                    // 2. شريط المؤشرات اليومية والأرصدة
                    _buildSummaryMetricsBar(),
                    const SizedBox(height: 16),

                    // 3. أزرار الإجراءات السريعة
                    _buildQuickActionsRow(),
                    const SizedBox(height: 20),

                    // 4. ترويسة سجل الحركات وفلاتر التدفق
                    _buildTransactionsSectionHeader(),
                    const SizedBox(height: 12),

                    // 5. قائمة حركات الصندوق النقدية
                    if (_transactions.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          return _buildTransactionCard(_transactions[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// بطاقة الرصيد الفعلي التراكمي للصندوق
  Widget _buildBalanceHeroCard() {
    final balance = _summary?.currentBalance ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'رصيد الصندوق الفعلي الآن',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'محسوب من سجل الحركات',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Formatters.formatCurrency(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ناتج عن: الرصيد الافتتاحي + المقبوضات - المدفوعات',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// شريط مؤشرات حركة اليوم والأرصدة التأسيسية
  Widget _buildSummaryMetricsBar() {
    final todayIn = _summary?.todayCashIn ?? 0;
    final todayOut = _summary?.todayCashOut ?? 0;
    final todayNet = _summary?.todayNet ?? 0;
    final opening = _summary?.openingBalance ?? 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'داخل اليوم',
                amount: todayIn,
                color: AppColors.success,
                icon: Icons.south_west,
              ),
            ),
            const VerticalDivider(width: 20, thickness: 1),
            Expanded(
              child: _buildMetricTile(
                title: 'خارج اليوم',
                amount: todayOut,
                color: AppColors.error,
                icon: Icons.north_east,
              ),
            ),
            const VerticalDivider(width: 20, thickness: 1),
            Expanded(
              child: _buildMetricTile(
                title: 'صافي اليوم',
                amount: todayNet,
                color: todayNet >= 0 ? AppColors.info : AppColors.warning,
                icon: Icons.sync_alt,
              ),
            ),
            const VerticalDivider(width: 20, thickness: 1),
            Expanded(
              child: _buildMetricTile(
                title: 'الافتتاحي',
                amount: opening,
                color: AppColors.secondary,
                icon: Icons.flag_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// أزرار العمليات السريعة (سحب، إيداع، رصيد افتتاحي)
  Widget _buildQuickActionsRow() {
    final hasOpening = (_summary?.openingBalance ?? 0) > 0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!hasOpening)
          ElevatedButton.icon(
            onPressed: _onSetOpeningBalance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_task),
            label: const Text('تسجيل الرصيد الافتتاحي'),
          ),
        ElevatedButton.icon(
          onPressed: _onRecordOtherDeposit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('إيداع نقدية أخرى'),
        ),
        OutlinedButton.icon(
          onPressed: _onRecordOwnerWithdrawal,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.purple.shade700,
            side: BorderSide(color: Colors.purple.shade300),
            minimumSize: const Size(150, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('سحب صاحب المحل'),
        ),
      ],
    );
  }

  /// ترويسة قسم سجل الحركات وفلاتر التدفق
  Widget _buildTransactionsSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'سجل حركات الصندوق',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_transactions.length} حركة',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        // فلاتر الاتجاه (الكل / وارد / صادر)
        Row(
          children: [
            ChoiceChip(
              label: const Text('الكل', style: TextStyle(fontSize: 12)),
              selected: _selectedDirectionFilter == null,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedDirectionFilter = null);
                  _loadCashboxData();
                }
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('وارد (+)', style: TextStyle(fontSize: 12)),
              selected: _selectedDirectionFilter == CashFlowDirection.cashIn,
              onSelected: (val) {
                setState(() => _selectedDirectionFilter = val ? CashFlowDirection.cashIn : null);
                _loadCashboxData();
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('صادر (-)', style: TextStyle(fontSize: 12)),
              selected: _selectedDirectionFilter == CashFlowDirection.cashOut,
              onSelected: (val) {
                setState(() => _selectedDirectionFilter = val ? CashFlowDirection.cashOut : null);
                _loadCashboxData();
              },
            ),
          ],
        ),
      ],
    );
  }

  /// بطاقة عرض حركة الصندوق الواحدة
  Widget _buildTransactionCard(CashTransaction tx) {
    final isIncome = tx.direction == CashFlowDirection.cashIn;
    final color = isIncome ? AppColors.success : AppColors.error;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => CashTransactionDetailsDialog.show(context, tx),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // أيقونة اتجاه الحركة
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.south_west : Icons.north_east,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // تفاصيل الحركة والبيان
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tx.type.arabicLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.description,
                        style: const TextStyle(
                          fontSize: 13,
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
                      Formatters.formatDateTime(tx.transactionDate),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (tx.runningBalance != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '| الرصيد بعدها: ${Formatters.formatCurrency(tx.runningBalance!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // المبلغ (+ أو -)
          Text(
            '${isIncome ? "+" : "-"}${Formatters.formatCurrency(tx.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
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
            Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا توجد حركات نقدية مسجلة في الصندوق حتى الآن',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'ستظهر هنا جميع حركات البيع، الشراء، دفعات العملاء، ودفعات الموردين تلقائياً.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
