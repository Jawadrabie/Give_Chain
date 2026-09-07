import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract final class ApiResponseCache {
  /// Bump this whenever a response's *shape* changes, to drop entries cached
  /// under the old contract.
  ///
  /// v2: case details gained `caseNeeds`/`caseUpdates`. Anything cached
  /// before that (up to 6 hours) still looked like a case with no needs, so
  /// the donation screen refused every case donation until the entry aged
  /// out. A new prefix retires those entries immediately.
  static const _prefix = 'givechain_api_cache_v2:';
  static SharedPreferences? _preferences;

  static Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _prefs {
    final value = _preferences;
    if (value == null) {
      throw StateError('ApiResponseCache.initialize must be called first.');
    }
    return value;
  }

  static Future<void> write(
    String path,
    Map<String, dynamic>? query,
    dynamic data,
  ) async {
    try {
      final encoded = jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      });
      await _prefs.setString(_key(path, query), encoded);
    } catch (_) {
      // A response that is not JSON encodable should never break the request.
    }
  }

  static dynamic read(
    String path,
    Map<String, dynamic>? query, {
    required Duration maxAge,
  }) {
    final raw = _prefs.getString(_key(path, query));
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map) return null;
      final savedAt = DateTime.tryParse(envelope['savedAt']?.toString() ?? '');
      if (savedAt == null) return null;
      if (DateTime.now().toUtc().difference(savedAt.toUtc()) > maxAge) {
        return null;
      }
      return envelope['data'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final keys = _prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  static String _key(String path, Map<String, dynamic>? query) {
    final entries = (query ?? const <String, dynamic>{}).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final queryText = entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    return '$_prefix$path?$queryText';
  }
}
