import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// بطاقة مرنة ومتجاوبة (Fluid & Flexible Responsive Card)
///
/// تلتزم بالقاعدة الذهبية:
/// 1. لا تحتوي على أي أبعاد ثابتة (Fixed width / height) أبداً، وتعتمد كلياً على التمدد التلقائي
///    حسب حجم المحتوى الداخلي والمساحة المتاحة في الشاشة.
/// 2. تضمن مسافات داخلية (Padding) مريحة ومتساوية (16px كحد أدنى) لمنع اختناق المحتوى.
/// 3. توفر مظهراً بصرياً عصرياً بحواف دائرية ناعمة (14px) وتظليل خفيف وأنيق (Soft Box Shadow)
///    مع إطار ناعم يفصلها عن الخلفية بارتياح تام للعين.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasShadow;
  final BoxConstraints? constraints;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16), // مسافة داخلية مريحة لا تقل عن 16px
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14.0, // حواف دائرية ناعمة وعصرية
    this.hasShadow = true,
    this.constraints,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.backgroundColor ?? AppColors.surface;
    final effectiveBorder = widget.borderColor ?? AppColors.border;

    // تم بناء الحاوية بـ BoxConstraints مرنة بدون أي أبعاد ثابتة
    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: widget.constraints ?? const BoxConstraints(),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: _isHovered && widget.onTap != null
              ? AppColors.primary.withAlpha(120)
              : effectiveBorder,
          width: 1.0,
        ),
        boxShadow: widget.hasShadow
            ? [
                BoxShadow(
                  // تظليل خفيف جداً وأنيق لتمييز البطاقة برقي عن الخلفية
                  color: _isHovered && widget.onTap != null
                      ? const Color(0x180F172A)
                      : const Color(0x0A0F172A),
                  blurRadius: _isHovered && widget.onTap != null ? 12 : 6,
                  offset: Offset(0, _isHovered && widget.onTap != null ? 4 : 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          splashColor: AppColors.primary.withAlpha(15),
          highlightColor: AppColors.primary.withAlpha(10),
          child: content,
        ),
      );
    }

    if (widget.margin != EdgeInsets.zero) {
      content = Padding(
        padding: widget.margin,
        child: content,
      );
    }

    return content;
  }
}
