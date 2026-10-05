import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sales/core/presentation/theme/app_theme.dart';

import '../core/presentation/constants/app_constants.dart';
import 'presentation/main_navigation_shell.dart';

/// التطبيق الرئيسي لنظام إدارة المفروشات
class FurnitureStoreApp extends StatelessWidget {
  final Widget? home;

  const FurnitureStoreApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale(AppConstants.defaultLocale),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home ?? const MainNavigationShell(),
    );
  }
}
