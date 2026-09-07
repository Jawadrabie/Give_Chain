import 'package:flutter/foundation.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_helpers.dart';
import '../../catalog/data/catalog_models.dart';
import 'notification_models.dart';

class NotificationRepository {
  NotificationRepository(this._client);
  final ApiClient _client;
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<PageResult<AppNotification>> list({
    int page = 1,
    int pageSize = 20,
  }) async {
    final raw = await _client.get(
      ApiPaths.notifications,
      query: {'page': page, 'pageSize': pageSize},
    );
    final items =
        JsonHelpers.objectList(raw).map(AppNotification.fromJson).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PageResult(
      items: items,
      hasMore: JsonHelpers.hasMorePage(
        raw,
        page: page,
        pageSize: pageSize,
        receivedCount: items.length,
      ),
    );
  }

  Future<int> refreshUnreadCount() async {
    final raw = JsonHelpers.unwrap(
      await _client.get(ApiPaths.notificationUnreadCount),
    );
    final count = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? 0;
    unreadCount.value = count;
    return count;
  }

  Future<void> markRead(String id) async {
    await _client.patch(ApiPaths.notificationRead(id));
    if (unreadCount.value > 0) unreadCount.value--;
  }

  Future<void> markAllRead() async {
    await _client.patch(ApiPaths.notificationReadAll);
    unreadCount.value = 0;
  }
}
