import 'package:flutter/material.dart';
import 'package:sales/core/data/constants/database_constants.dart';
import 'package:sales/core/data/database/database_service.dart';
import 'package:sales/core/domain/errors/error_handler.dart';
import 'package:sales/core/presentation/constants/app_constants.dart';
import 'package:sales/core/presentation/theme/app_colors.dart';
import 'package:sales/core/presentation/utils/formatters.dart';
import '../../data/repositories/store_settings_repository_impl.dart';
import '../../domain/entities/store_profile.dart';
import '../../domain/repositories/store_settings_repository.dart';

/// شاشة التحقق التأسيسية للنظام (المرحلة الأولى)
/// تتبع طبقة العرض (Presentation) لميزة إعدادات المتجر (Settings Feature)
class FoundationScreen extends StatefulWidget {
  final StoreSettingsRepository? repository;
  final DatabaseService? databaseService;
  final StoreProfile? initialProfile;

  const FoundationScreen({
    super.key,
    this.repository,
    this.databaseService,
    this.initialProfile,
  });

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> {
  late final DatabaseService _databaseService;
  late final StoreSettingsRepository _repository;
  StoreProfile? _storeProfile;
  late bool _isLoading;
  String? _errorMessage;
  bool _isDbConnected = false;

  @override
  void initState() {
    super.initState();
    _storeProfile = widget.initialProfile;
    _isLoading = widget.initialProfile == null;
    _databaseService = widget.databaseService ?? DatabaseService.instance;
    _repository =
        widget.repository ??
        StoreSettingsRepositoryImpl(databaseService: _databaseService);

    if (widget.initialProfile == null) {
      _checkSystemHealth();
    } else {
      _isDbConnected = true;
    }
  }

  Future<void> _checkSystemHealth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_databaseService.isOpen) {
        _isDbConnected = true;
      } else {
        final db = await _databaseService.database;
        _isDbConnected = db.isOpen;
      }

      final profile = await _repository.getStoreProfile();

      if (mounted) {
        setState(() {
          _storeProfile = profile;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'إعادة فحص سلامة النظام',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkSystemHealth,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // بطاقة الترحيب والجاهزية
                _buildHeaderCard(),
                const SizedBox(height: 20),

                // بطاقة حالة قاعدة البيانات SQLite
                _buildDatabaseStatusCard(),
                const SizedBox(height: 20),

                // بطاقة بيانات المتجر الأساسية (من خلال المستودع)
                _buildStoreProfileCard(),
                const SizedBox(height: 20),

                // بطاقة مؤشرات المعمارية
                _buildArchitectureCheckCard(),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  _buildErrorBanner(_errorMessage!),
                ],
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chair_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _storeProfile?.name ?? AppConstants.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المرحلة 1: اكتمال تأسيس البنية التحتية وقاعدة البيانات',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDbConnected ? Icons.check_circle : Icons.error,
                  color: _isDbConnected ? AppColors.success : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'حالة محرك التخزين المحلي (SQLite)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isDbConnected
                        ? AppColors.successContainer
                        : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isDbConnected ? 'متصل وجاهز' : 'غير متصل',
                    style: TextStyle(
                      color: _isDbConnected
                          ? AppColors.success
                          : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildInfoRow(
              'اسم قاعدة البيانات:',
              DatabaseConstants.databaseName,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              'إصدار المخطط الحالي:',
              'الإصدار ${DatabaseConstants.databaseVersion}',
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              'نظام الهجرات (Migrations):',
              'مفعل ويعمل بالتسلسل التلقائي',
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              'القيود المرجعية (Foreign Keys):',
              'مفعلة عبر PRAGMA',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreProfileCard() {
    final profile = _storeProfile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: AppColors.secondary,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'بيانات المنشأة التأسيسية (Clean Architecture)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            if (profile != null) ...[
              _buildInfoRow('اسم المتجر:', profile.name),
              const SizedBox(height: 10),
              _buildInfoRow('العملة الافتراضية:', profile.currency),
              const SizedBox(height: 10),
              _buildInfoRow(
                'تاريخ التحديث:',
                AppFormatters.dateTime(profile.updatedAt),
              ),
            ] else ...[
              const Text(
                'لم يتم تحميل بيانات المتجر بعد.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureCheckCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.layers_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المعايير المعمارية المحققة في المرحلة الأولى',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildCheckItem(
              'Clean Architecture: فصل Presentation عن Domain وعن Data',
            ),
            _buildCheckItem(
              'عزل محرك SQLite التام عن واجهات المستخدم والـ Domain',
            ),
            _buildCheckItem(
              'Repository Pattern لتنفيذ مصادر البيانات مع معالجة الأخطاء',
            ),
            _buildCheckItem(
              'فصل نماذج البيانات (Models) عن كيانات النطاق (Entities) عبر Mappers',
            ),
            _buildCheckItem(
              'نظام سمات مركزي (Material 3) متوافق مع الاتجاه العربي RTL',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
