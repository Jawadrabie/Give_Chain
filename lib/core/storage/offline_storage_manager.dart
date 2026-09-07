import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/centers/data/center_models.dart';

abstract final class OfflineStorageManager {
  static const _cachedCentersKey = 'givechain_offline_centers_v1';
  static const _offlineSyncQueueKey = 'givechain_offline_sync_queue_v1';

  static Future<void> saveCenters(List<CenterResponse> centers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = centers
        .map(
          (item) => {
            'id': item.id,
            'name': item.name,
            'countryId': item.countryId,
            'countryName': item.countryName,
            'cityId': item.cityId,
            'cityName': item.cityName,
            'addressDetails': item.addressDetails,
          },
        )
        .toList();
    await prefs.setString(_cachedCentersKey, jsonEncode(jsonList));
  }

  static Future<List<CenterResponse>> getCachedCenters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedCentersKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map(CenterResponse.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> enqueueOfflineAction(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getOfflineQueue();
    queue.add(action);
    await prefs.setString(_offlineSyncQueueKey, jsonEncode(queue));
  }

  static Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineSyncQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineSyncQueueKey);
  }

  static Future<void> setOfflineQueue(
    List<Map<String, dynamic>> queue,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_offlineSyncQueueKey);
    } else {
      await prefs.setString(_offlineSyncQueueKey, jsonEncode(queue));
    }
  }
}
