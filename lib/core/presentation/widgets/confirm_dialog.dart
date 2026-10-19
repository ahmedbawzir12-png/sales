import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// مربع حوار موحد لتأكيد العمليات المالية والمخزنية الحساسة (Unified Confirm Dialog)
/// يوضح للمستخدم بدقة أثر العملية ومبالغها قبل الاعتماد، ويمنع النقرات المتكررة
class ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? impactExplanation;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final Color iconColor;
  final bool isDestructive;
  final Widget? customContent;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.impactExplanation,
    this.confirmLabel = 'تأكيد',
    this.cancelLabel = 'إلغاء',
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = AppColors.warning,
    this.isDestructive = false,
    this.customContent,
  });

  /// دالة مساعدة لفتح مربع الحوار بسهولة
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? impactExplanation,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = AppColors.warning,
    bool isDestructive = false,
    Widget? customContent,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        impactExplanation: impactExplanation,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        iconColor: iconColor,
        isDestructive: isDestructive,
        customContent: customContent,
      ),
    );
    return result ?? false;
  }

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmColor = widget.isDestructive ? AppColors.error : AppColors.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            if (widget.impactExplanation != null &&
                widget.impactExplanation!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.impactExplanation!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.customContent != null) ...[
              const SizedBox(height: 12),
              widget.customContent!,
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: Text(
            widget.cancelLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing
              ? null
              : () {
                  setState(() => _isProcessing = true);
                  Navigator.of(context).pop(true);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.confirmLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
