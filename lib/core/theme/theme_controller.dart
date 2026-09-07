import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Holds the user's appearance choice for the entire app.
///
/// First install (no saved value) → [ThemeMode.system] (device theme).
/// After a manual toggle → light/dark is persisted and synced to native so
/// the next cold-start splash matches the choice.
abstract final class ThemeController {
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static const _storageKey = 'givechain_theme_mode';
  static const _nativeChannel = MethodChannel('givechain/theme');

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    switch (preferences.getString(_storageKey)) {
      case 'light':
        mode.value = ThemeMode.light;
      case 'dark':
        mode.value = ThemeMode.dark;
      default:
        mode.value = ThemeMode.system;
    }
    await _syncNative(mode.value);
    applySystemBars(mode.value);
  }

  static Future<void> toggle(Brightness currentBrightness) async {
    final isDark =
        mode.value == ThemeMode.dark ||
        (mode.value == ThemeMode.system &&
            currentBrightness == Brightness.dark);
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      mode.value == ThemeMode.dark ? 'dark' : 'light',
    );
    await _syncNative(mode.value);
    applySystemBars(mode.value);
  }

  /// Paints the status/navigation bar to match [mode] immediately.
  ///
  /// The native side (`AppCompatDelegate.setDefaultNightMode`) only
  /// re-applies the day/night `styles.xml` colors when the Activity is an
  /// `AppCompatActivity` and gets recreated. GiveChain's `MainActivity` is a
  /// plain `FlutterActivity`, so a mid-session toggle never recreates it and
  /// the real status bar keeps its previous color even though Flutter's own
  /// UI repaints instantly. Setting it here bypasses that entirely.
  static void applySystemBars(
    ThemeMode mode, {
    Brightness? platformBrightness,
  }) {
    final resolved = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        platformBrightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    final isDark = resolved == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark
            ? AppTheme.darkBackground
            : AppTheme.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  static Future<void> _syncNative(ThemeMode themeMode) async {
    final name = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      await _nativeChannel.invokeMethod<void>('setNightMode', {'mode': name});
    } catch (_) {
      // Native channel unavailable on unsupported platforms / tests.
    }
  }
}
