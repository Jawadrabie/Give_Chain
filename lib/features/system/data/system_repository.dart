import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';

class SystemRepository {
  const SystemRepository(this._client);
  final ApiClient _client;

  Future<String> backendVersion() async {
    final raw = await _client.get(
      ApiPaths.version,
      requiresAuth: false,
      cacheTtl: const Duration(hours: 6),
    );
    final data = JsonHelpers.unwrap(raw);
    if (data is Map) {
      return JsonHelpers.text(Map<String, dynamic>.from(data), const [
        'version',
      ], fallback: 'غير معروف');
    }
    return data?.toString() ?? 'غير معروف';
  }

  Future<String> charityIdBySubdomain(String subdomain) async {
    final value = subdomain.trim();
    if (value.isEmpty) {
      throw const ApiFailure('رابط الجمعية غير مكتمل.');
    }
    final raw = await _client.get(
      ApiPaths.charityLookupBySubdomain(value),
      requiresAuth: false,
      cacheTtl: const Duration(minutes: 30),
    );
    final data = JsonHelpers.unwrap(raw);
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is Map) {
      final id = JsonHelpers.text(Map<String, dynamic>.from(data), const [
        'id',
        'charityId',
      ]);
      if (id.isNotEmpty) return id;
    }
    throw const ApiFailure('لم يتم العثور على الجمعية المرتبطة بهذا الرابط.');
  }
}
