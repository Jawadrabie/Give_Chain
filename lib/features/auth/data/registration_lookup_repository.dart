import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_helpers.dart';
import 'registration_lookup_models.dart';

class RegistrationLookupRepository {
  const RegistrationLookupRepository(this._client);
  final ApiClient _client;

  Future<List<ReferenceOption>> countries() async {
    final raw = await _client.get(
      ApiPaths.countries,
      requiresAuth: false,
      cacheTtl: const Duration(days: 1),
    );
    return JsonHelpers.objectList(raw).map(ReferenceOption.fromJson).toList();
  }

  Future<List<ReferenceOption>> cities() async {
    final raw = await _client.get(
      ApiPaths.citiesPath,
      requiresAuth: false,
      cacheTtl: const Duration(days: 1),
    );
    return JsonHelpers.objectList(raw).map(ReferenceOption.fromJson).toList();
  }

  Future<List<ReferenceOption>> caseCategories({
    String? charityId,
    String? charityCategoryId,
  }) async {
    final raw = await _client.get(
      ApiPaths.caseCategories,
      query: {
        if (charityId?.trim().isNotEmpty == true)
          'charityId': charityId!.trim(),
        if (charityCategoryId?.trim().isNotEmpty == true)
          'charityCategoryId': charityCategoryId!.trim(),
      },
      requiresAuth: false,
      cacheTtl: const Duration(hours: 6),
    );
    return JsonHelpers.objectList(raw).map(ReferenceOption.fromJson).toList();
  }

  Future<List<ReferenceOption>> campaignTypes({
    String? charityId,
    String? charityCategoryId,
  }) async {
    final raw = await _client.get(
      ApiPaths.campaignTypes,
      query: {
        if (charityId?.trim().isNotEmpty == true)
          'charityId': charityId!.trim(),
        if (charityCategoryId?.trim().isNotEmpty == true)
          'charityCategoryId': charityCategoryId!.trim(),
      },
      requiresAuth: false,
      cacheTtl: const Duration(hours: 6),
    );
    return JsonHelpers.objectList(raw).map(ReferenceOption.fromJson).toList();
  }
}
