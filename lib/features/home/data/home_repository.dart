import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import '../../catalog/data/catalog_models.dart';
import 'home_overview.dart';

class HomeRepository {
  const HomeRepository(this._client);
  final ApiClient _client;

  /// الحد الأدنى لعدد الجمعيات المعروضة في الشريط الرئيسي.
  static const _minHomeCharities = 10;

  Future<HomeOverview> load({bool forceRefresh = false}) async {
    final raw = JsonHelpers.unwrap(
      await _client.get(
        ApiPaths.home,
        requiresAuth: false,
        cacheTtl: const Duration(minutes: 20),
        forceRefresh: forceRefresh,
      ),
    );
    if (raw is! Map) throw const ApiFailure('تعذر قراءة الصفحة الرئيسية.');
    final json = Map<String, dynamic>.from(raw);
    List<Map<String, dynamic>> maps(String key) =>
        (json[key] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

    var charities = maps('recentCharities').map(Charity.fromJson).toList();
    if (charities.length < _minHomeCharities) {
      charities = await _loadCharitiesFallback(
        prefer: charities,
        forceRefresh: forceRefresh,
      );
    }

    return HomeOverview(
      campaigns: maps('featuredCampaigns').map(CatalogItem.fromJson).toList(),
      charities: charities,
      cases: maps('recentCases').map(CatalogItem.fromJson).toList(),
    );
  }

  /// الـ API الرئيسي قد يعيد جمعية واحدة فقط في `recentCharities`.
  /// نكمّل من قائمة الجمعيات الكاملة حتى يظهر شريط غني في الصفحة الرئيسية.
  Future<List<Charity>> _loadCharitiesFallback({
    required List<Charity> prefer,
    bool forceRefresh = false,
  }) async {
    try {
      final raw = await _client.get(
        ApiPaths.charities,
        query: {'page': 1, 'pageSize': _minHomeCharities},
        cacheTtl: const Duration(minutes: 30),
        forceRefresh: forceRefresh,
        requiresAuth: false,
      );
      final fromList = JsonHelpers.objectList(
        raw,
      ).map(Charity.fromJson).toList();
      if (fromList.isEmpty) return prefer;

      final seen = <String>{};
      final merged = <Charity>[];
      for (final charity in [...prefer, ...fromList]) {
        if (charity.id.isEmpty || !seen.add(charity.id)) continue;
        merged.add(charity);
        if (merged.length >= _minHomeCharities) break;
      }
      return merged.isEmpty ? prefer : merged;
    } catch (_) {
      return prefer;
    }
  }
}
