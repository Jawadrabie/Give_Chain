import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_helpers.dart';
import '../../../core/storage/offline_storage_manager.dart';
import 'center_models.dart';

class CenterRepository {
  const CenterRepository(this._client);
  final ApiClient _client;

  Future<List<CenterResponse>> getCenters({
    String? cityId,
    String? countryId,
  }) async {
    final query = <String, dynamic>{};
    if (cityId?.trim().isNotEmpty == true) query['cityId'] = cityId!.trim();
    if (countryId?.trim().isNotEmpty == true) query['countryId'] = countryId!.trim();

    try {
      final raw = await _client.get(
        ApiPaths.centers,
        query: query.isEmpty ? null : query,
      );
      final list = JsonHelpers.objectList(raw).map(CenterResponse.fromJson).toList();
      await OfflineStorageManager.saveCenters(list);
      return list;
    } catch (error) {
      final cached = await OfflineStorageManager.getCachedCenters();
      if (cached.isEmpty) rethrow;
      final filtered = cached
          .where(
            (center) =>
                (cityId?.trim().isEmpty ?? true) || center.cityId == cityId,
          )
          .where(
            (center) =>
                (countryId?.trim().isEmpty ?? true) ||
                center.countryId == countryId,
          )
          .toList();
      return filtered.isNotEmpty ? filtered : cached;
    }
  }
}
