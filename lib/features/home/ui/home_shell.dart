import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/pending_route_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_logo.dart';
import '../../notifications/data/notification_repository.dart';
import '../../profile/ui/profile_screen.dart';
import 'dashboard_screen.dart';
import 'quick_donate_screen.dart';

/// يسمح للشاشات الفرعية بالتبديل بين تبويبات الشريط السفلي.
class HomeTabScope extends InheritedWidget {
  const HomeTabScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final ValueChanged<int> selectTab;

  static HomeTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabScope>();

  @override
  bool updateShouldNotify(HomeTabScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  static const titles = ['الرئيسية', 'تبرع', 'حسابي'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _synchronizeSession());
  }

  Future<void> _synchronizeSession() async {
    await TokenStorage.synchronize();
    if (!mounted) return;
    setState(() {});
    if (!TokenStorage.hasSession) return;

    context.read<NotificationRepository>().refreshUnreadCount().catchError(
      (_) => 0,
    );

    final pendingRoute = await PendingRouteStorage.consume();
    if (!mounted || pendingRoute == null || pendingRoute == '/home') return;
    context.go(pendingRoute);
  }

  void _select(int value) {
    if (!TokenStorage.hasSession && value == 2) {
      context.push('/profile');
      return;
    }
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = TokenStorage.hasSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return HomeTabScope(
      selectTab: _select,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: index == 0
              ? Row(
                  children: [
                    const AppLogo(size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'GiveChain',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                )
              : Text(titles[index]),
          backgroundColor: scaffoldBg,
          actions: [
            IconButton(
              tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
              onPressed: () =>
                  ThemeController.toggle(Theme.of(context).brightness),
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(
          index: index,
          sizing: StackFit.expand,
          children: [
            const DashboardScreen(),
            const QuickDonateScreen(),
            authenticated
                ? const ProfileScreen()
                : const _SignInRequired(key: ValueKey('profile-guest')),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: AppTheme.softOf(context),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'تبرع',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 64),
          const SizedBox(height: 12),
          const Text(
            'سجّل الدخول للمتابعة',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    ),
  );
}
