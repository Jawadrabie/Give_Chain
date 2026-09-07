import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/jwt_token.dart';
import '../session/session_controller.dart';

abstract final class TokenStorage {
  static const _tokenKey = 'access_token';
  static const _legacyTokenKey = 'isLogin';
  static const _rememberSessionKey = 'remember_session';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static SharedPreferences? _preferences;
  static String? _token;

  static Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final remember = _prefs.getBool(_rememberSessionKey) ?? true;
    if (!remember) {
      await _clearInternal();
      return;
    }
    await synchronize(notify: false);
  }

  static SharedPreferences get _prefs {
    final value = _preferences;
    if (value == null) {
      throw StateError('TokenStorage.initialize must be called before use.');
    }
    return value;
  }

  static String? get token => _token;

  static JwtTokenInfo? get tokenInfo {
    final value = _token;
    return value == null ? null : JwtTokenInfo.tryParse(value);
  }

  static bool get hasSession {
    final value = _token;
    if (value == null || value.trim().isEmpty) return false;
    return tokenInfo?.isExpired != true;
  }

  /// Refreshes values written by the unchanged legacy Login feature and
  /// migrates them to encrypted storage. This is intentionally compatible
  /// with the original `isLogin` key.
  static Future<void> synchronize({bool notify = true}) async {
    await _prefs.reload();
    final secure = await _secureRead();
    final legacyValue = _prefs.get(_legacyTokenKey);
    final standardValue = _prefs.get(_tokenKey);
    final legacy = legacyValue is String ? legacyValue : null;
    final standard = standardValue is String ? standardValue : null;
    final candidate = _firstValid([secure, standard, legacy]);
    final hadStoredValue =
        _token != null ||
        (secure != null && secure.trim().isNotEmpty) ||
        (standard != null && standard.trim().isNotEmpty) ||
        (legacy != null && legacy.trim().isNotEmpty);

    if (candidate == null ||
        JwtTokenInfo.tryParse(candidate)?.isExpired == true) {
      await _clearInternal();
      if (notify && hadStoredValue) {
        SessionController.instance.notifyChanged();
      }
      return;
    }

    final changed = _token != candidate;
    _token = candidate;
    await _secureWrite(candidate);
    await _prefs.setString(_tokenKey, candidate);
    // Keep legacy Login compatible without modifying its source.
    await _prefs.setString(_legacyTokenKey, candidate);
    if (notify && changed) SessionController.instance.notifyChanged();
  }

  static Future<bool> ensureValidSession() async {
    if (!hasSession) await synchronize();
    if (!hasSession) {
      await clear();
      return false;
    }
    return true;
  }

  static bool get remembersSession =>
      _prefs.getBool(_rememberSessionKey) ?? true;

  /// Controls whether the authenticated session survives the next app start.
  /// A non-remembered token remains usable for the current process and is
  /// cleared when [initialize] runs on the following launch.
  static Future<void> setRememberSession(bool remember) async {
    await _prefs.setBool(_rememberSessionKey, remember);
  }

  static Future<void> saveToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      await clear();
      return;
    }
    _token = value;
    await _secureWrite(value);
    await _prefs.setString(_tokenKey, value);
    await _prefs.setString(_legacyTokenKey, value);
    SessionController.instance.notifyChanged();
  }

  static Future<void> clear() async {
    final hadSession =
        _token != null ||
        _prefs.containsKey(_tokenKey) ||
        _prefs.containsKey(_legacyTokenKey);
    await _clearInternal();
    if (hadSession) SessionController.instance.notifyChanged();
  }

  static Future<void> _clearInternal() async {
    _token = null;
    await _secureDelete();
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_legacyTokenKey);
  }

  static Future<String?> _secureRead() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _secureWrite(String value) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: value);
    } catch (_) {
      // SharedPreferences remains as a compatibility fallback for the
      // unchanged Login implementation and devices without secure storage.
    }
  }

  static Future<void> _secureDelete() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // Clearing the SharedPreferences values below still ends the session.
    }
  }

  static String? _firstValid(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
