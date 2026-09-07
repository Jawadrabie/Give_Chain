import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/token_storage.dart';
import 'donation_models.dart';

class DonationHistoryStore {
  DonationHistoryStore(this._preferences);

  static const _baseKey = 'givechain_donation_history_v2';
  static const maxRecords = 100;

  final SharedPreferences _preferences;

  static Future<DonationHistoryStore> create() async {
    return DonationHistoryStore(await SharedPreferences.getInstance());
  }

  List<DonationRecord> readAll() {
    final raw = _preferences.getString(_currentKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final records = decoded
          .whereType<Map>()
          .map(
            (item) => DonationRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(DonationRecord record) => upsertAll([record]);

  Future<void> upsertAll(Iterable<DonationRecord> incoming) async {
    final byKey = <String, DonationRecord>{};
    for (final item in [...incoming, ...readAll()]) {
      final key = item.remoteId?.trim().isNotEmpty == true
          ? 'remote:${item.remoteId}'
          : 'local:${item.localId}';
      byKey.putIfAbsent(key, () => item);
    }
    final records = byKey.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _preferences.setString(
      _currentKey,
      jsonEncode(
        records.take(maxRecords).map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> clear() => _preferences.remove(_currentKey);

  String get _currentKey {
    final userId = TokenStorage.tokenInfo?.userId?.trim();
    return userId == null || userId.isEmpty
        ? '$_baseKey:guest'
        : '$_baseKey:$userId';
  }
}
