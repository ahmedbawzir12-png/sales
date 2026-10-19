import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نوع التنبيه لتحديد اللون والأيقونة المناسبة للعملية
enum ToastType {
  /// عمليات الحفظ والإضافة وسداد الدفعات (أخضر زمردي)
  save,

  /// عمليات الحذف والإلغاء (أحمر ناصع)
  delete,

  /// عمليات التعديل والتحديث وتغيير الحالة (أزرق نيلي / بترولي)
  update,

  /// التنبيهات والتحذيرات مثل نقص المخزون (برتقالي عنبري دافئ)
  warning,

  /// أخطاء النظام وفشل العمليات (أحمر داكن / قرمزي)
  error,

  /// المعلومات العامة وأوامر الطباعة والتصدير (كحلي رصين)
  info,
}

/// فئة مخصصة لإظهار إشعارات التوست (Toast) الفاخرة بدلاً من السناك بار التقليدي
class AppToast {
  AppToast._();

  /// مفتاح التنقل العام للوصول إلى الـ Overlay حتى في حال مغادرة الشاشة
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;
  static _AppToastWidgetState? _activeWidgetState;

  /// إظهار توست حفظ (أخضر)
  static void showSave(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      type: ToastType.save,
      duration: duration,
    );
  }

  /// إظهار توست حذف (أحمر)
  static void showDelete(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      type: ToastType.delete,
      duration: duration,
    );
  }

  /// إظهار توست تعديل وتحديث (أزرق نيلي / بترولي)
  static void showUpdate(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      type: ToastType.update,
      duration: duration,
    );
  }

  /// إظهار توست تنبيه / تحذير (برتقالي عنبري)
  static void showWarning(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration,
    );
  }

  /// إظهار توست خطأ / فشل (أحمر داكن)
  static void showError(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      duration: duration,
    );
  }

  /// إظهار توست معلومات أو طباعة (كحلي رصين)
  static void showInfo(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      duration: duration,
    );
  }

  /// إظهار التوست العام مع تحديد النوع أو اللون المخصص
  static void show(
    BuildContext? context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2800),
    Color? customColor,
    IconData? customIcon,
  }) {
    dismiss();

    final overlayState = _resolveOverlay(context);
    if (overlayState == null) {
      // ملاذ أخير إن لم يتم العثور على Overlay في البيئات الاختبارية المعزولة
      if (context != null && context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          final config = _getStyleConfig(type, customColor, customIcon);
          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: config.backgroundColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    final config = _getStyleConfig(type, customColor, customIcon);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppToastWidget(
        key: UniqueKey(),
        message: message,
        duration: duration,
        config: config,
        onDismiss: () => dismiss(),
        onReady: (state) {
          _activeWidgetState = state;
        },
      ),
    );

    _activeEntry = entry;
    overlayState.insert(entry);
  }

  /// إخفاء أي توست نشط حالياً مع حركة خروج ناعمة
  static void dismiss({bool immediate = false}) {
    _activeTimer?.cancel();
    _activeTimer = null;

    final entry = _activeEntry;
    final state = _activeWidgetState;

    _activeEntry = null;
    _activeWidgetState = null;

    if (entry != null && entry.mounted) {
      if (!immediate && state != null && state.mounted) {
        state.animateOut().then((_) {
          if (entry.mounted) {
            entry.remove();
          }
        });
      } else {
        entry.remove();
      }
    }
  }

  static OverlayState? _resolveOverlay(BuildContext? context) {
    if (context != null && context.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) return overlay;
    }
    return navigatorKey.currentState?.overlay;
  }

  static _ToastStyleConfig _getStyleConfig(
    ToastType type,
    Color? customColor,
    IconData? customIcon,
  ) {
    Color bg;
    IconData icon;

    switch (type) {
      case ToastType.save:
        // أخضر زاهٍ وموثوق لعمليات الحفظ والإضافة
        bg = customColor ?? const Color(0xFF059669);
        icon = customIcon ?? Icons.check_circle_rounded;
        break;
      case ToastType.delete:
        // أحمر للعمليات الإلغائية والحذف
        bg = customColor ?? const Color(0xFFDC2626);
        icon = customIcon ?? Icons.delete_outline_rounded;
        break;
      case ToastType.update:
        // أزرق بترولي أنيق للتعديلات وتغيير الحالات
        bg = customColor ?? const Color(0xFF0D9488);
        icon = customIcon ?? Icons.sync_rounded;
        break;
      case ToastType.warning:
        // برتقالي عنبري دافئ ومريح للنظر للتنبيهات
        bg = customColor ?? const Color(0xFFD97706);
        icon = customIcon ?? Icons.warning_amber_rounded;
        break;
      case ToastType.error:
        // أحمر داكن للأخطاء البرمجية وفشل المعالجة
        bg = customColor ?? const Color(0xFFB91C1C);
        icon = customIcon ?? Icons.error_outline_rounded;
        break;
      case ToastType.info:
        // كحلي رصين لهوية النظام للمعلومات والطباعة
        bg = customColor ?? AppColors.primary;
        icon = customIcon ?? Icons.info_outline_rounded;
        break;
    }

    return _ToastStyleConfig(
      backgroundColor: bg,
      icon: icon,
    );
  }
}

class _ToastStyleConfig {
  final Color backgroundColor;
  final IconData icon;

  const _ToastStyleConfig({
    required this.backgroundColor,
    required this.icon,
  });
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final _ToastStyleConfig config;
  final VoidCallback onDismiss;
  final ValueChanged<_AppToastWidgetState> onReady;

  const _AppToastWidget({
    super.key,
    required this.message,
    required this.duration,
    required this.config,
    required this.onDismiss,
    required this.onReady,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));

    widget.onReady(this);
    _controller.forward().then((_) {
      if (mounted) {
        _autoDismissTimer = Timer(widget.duration, () {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  Future<void> animateOut() async {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.config.backgroundColor;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) < 0) {
                          widget.onDismiss();
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 500,
                          minWidth: 260,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: bg.withValues(alpha: 0.36),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.config.icon,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: widget.onDismiss,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
