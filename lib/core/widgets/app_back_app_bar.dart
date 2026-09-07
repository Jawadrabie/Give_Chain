import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// رجوع موحّد: يغلق الصفحة إن أمكن، وإلا ينتقل لمسار احتياطي.
abstract final class AppNavigation {
  static void back(BuildContext context, {String fallbackRoute = '/home'}) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackRoute);
  }
}

/// AppBar مع سهم رجوع ظاهر دائمًا في الصفحات الثانوية (مهم مع GoRouter و`go`).
class AppBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppBackAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackRoute = '/home',
    this.showBack = true,
    this.centerTitle,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String fallbackRoute;
  final bool showBack;
  final bool? centerTitle;

  /// يطابق `AppTheme` (`toolbarHeight: 52`).
  static const double toolbarHeight = 52;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: () =>
                  AppNavigation.back(context, fallbackRoute: fallbackRoute),
            )
          : null,
    );
  }
}
