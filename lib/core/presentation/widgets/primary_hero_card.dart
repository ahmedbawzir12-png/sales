import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// بطاقة هيرو موحدة بالهوية الزرقاء الداكنة للنظام
///
/// تم استخراج هذا النمط مباشرة وبدقة متطابقة من حاوية "رصيد الصندوق الفعلي الآن":
/// - اللون الأساسي الداكن المرجعي: [AppColors.primary] (#1E3A8A)
/// - نصوص بيضاء عالية التباين وواضحة جداً للعين
/// - شارة دائرية شبه شفافة أنيقة في الركن الأيسر
/// - حواف دائرية ناعمة (14px) مع هوامش ومسافات داخلية متناسقة
/// - مرونة كاملة في التمدد بدون أي أبعاد ثابتة (Fluid & Flexible)
class PrimaryHeroCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? badge;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PrimaryHeroCard({
    super.key,
    this.icon,
    required this.title,
    this.badge,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AppCard(
        padding: padding,
        backgroundColor: AppColors.primary,
        borderColor: Colors.transparent,
        borderRadius: 14.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ترويسة الحاوية الموحدة (أيقونة + عنوان + شارة توضيحية)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (badge != null && badge!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(46), // Colors.white with 18% opacity
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// عنصر مؤشر مالي/إحصائي داخل بطاقة الهيرو الموحدة
class PrimaryHeroMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final String? subtitle;

  const PrimaryHeroMetricItem({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onTap,
    this.isSelected = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ?? Colors.white;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withAlpha(35) : Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? Colors.white.withAlpha(120) : Colors.white.withAlpha(35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: effectiveValueColor,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      );
    }

    return content;
  }
}
