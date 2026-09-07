import 'package:shared_preferences/shared_preferences.dart';

/// Stores the protected destination that a guest attempted to open.
///
/// The original Login screen is intentionally left unchanged. After it saves
/// the legacy token and navigates to Home, [HomeShell] consumes this route and
/// continues the user's original action.
abstract final class PendingRouteStorage {
  static const _key = 'givechain_pending_route';

  static Future<void> save(String route) async {
    final value = route.trim();
    if (value.isEmpty || value == '/login' || value.startsWith('/login?')) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }

  static Future<String?> consume() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final value = preferences.getString(_key)?.trim();
    await preferences.remove(_key);
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
