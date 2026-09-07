import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import 'catalog_models.dart';

class CatalogRepository {
  const CatalogRepository(this._client);
  final ApiClient _client;

  Future<PageResult<CatalogItem>> campaigns({
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(
    ApiPaths.campaigns,
    page: page,
    pageSize: pageSize,
    filter: filter,
  );

  Future<PageResult<CatalogItem>> cases({
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(ApiPaths.cases, page: page, pageSize: pageSize, filter: filter);

  /// [forceRefresh] bypasses the cache. Use it wherever a stale copy would
  /// actively mislead — above all the donation form, whose `caseNeeds` and
  /// progress figures move every time somebody donates.
  Future<CatalogItem> campaign(String id, {bool forceRefresh = false}) =>
      _item(ApiPaths.campaign(id), forceRefresh: forceRefresh);

  Future<CatalogItem> caseById(String id, {bool forceRefresh = false}) =>
      _item(ApiPaths.caseById(id), forceRefresh: forceRefresh);

  Future<PageResult<Charity>> charities({
    int page = 1,
    int pageSize = 10,
    String search = '',
    String category = '',
    bool onlyTrusted = false,
  }) async {
    final hasLocalFilter = search.trim().isNotEmpty || category.trim().isNotEmpty || onlyTrusted;
    if (hasLocalFilter) {
      if (page > 1) return const PageResult(items: [], hasMore: false);
      final all = <Charity>[];
      const scanSize = 50;
      for (var scanPage = 1; scanPage <= 100; scanPage++) {
        final raw = await _client.get(
          ApiPaths.charities,
          query: {'page': scanPage, 'pageSize': scanSize},
          cacheTtl: const Duration(minutes: 30),
          requiresAuth: false,
        );
        final maps = JsonHelpers.objectList(raw);
        all.addAll(maps.map(Charity.fromJson));
        if (!JsonHelpers.hasMorePage(
          raw,
          page: scanPage,
          pageSize: scanSize,
          receivedCount: maps.length,
        )) {
          break;
        }
      }
      final ids = <String>{};
      final filtered = all
          .where((item) => item.matches(search))
          .where((item) => category.trim().isEmpty || item.categoryName == category.trim() || item.categoryNames.contains(category.trim()))
          .where((item) => !onlyTrusted || item.isTrusted)
          .where((item) => ids.add(item.id))
          .toList();
      return PageResult(items: filtered, hasMore: false);
    }

    final raw = await _client.get(
      ApiPaths.charities,
      query: {'page': page, 'pageSize': pageSize},
      cacheTtl: const Duration(minutes: 30),
      requiresAuth: false,
    );
    final maps = JsonHelpers.objectList(raw);
    return PageResult(
      items: maps.map(Charity.fromJson).toList(),
      hasMore: JsonHelpers.hasMorePage(
        raw,
        page: page,
        pageSize: pageSize,
        receivedCount: maps.length,
      ),
    );
  }

  Future<Charity> charity(String id) async {
    final raw = JsonHelpers.unwrap(
      await _client.get(
        ApiPaths.charity(id),
        cacheTtl: const Duration(hours: 6),
        requiresAuth: false,
      ),
    );
    if (raw is! Map) throw const ApiFailure('تعذر قراءة بيانات الجمعية.');
    return Charity.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<PageResult<CatalogItem>> charityCampaigns(
    String charityId, {
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(
    ApiPaths.charityCampaigns(charityId),
    page: page,
    pageSize: pageSize,
    filter: filter,
  );

  Future<PageResult<CatalogItem>> charityCases(
    String charityId, {
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(
    ApiPaths.charityCases(charityId),
    page: page,
    pageSize: pageSize,
    filter: filter,
  );

  Future<PageResult<CatalogItem>> campaignsByCharity(
    String charityId, {
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(
    ApiPaths.campaignsByCharity(charityId),
    page: page,
    pageSize: pageSize,
    filter: filter,
  );

  Future<PageResult<CatalogItem>> casesByCharity(
    String charityId, {
    int page = 1,
    int pageSize = 10,
    CatalogQuery filter = const CatalogQuery(),
  }) => _items(
    ApiPaths.casesByCharity(charityId),
    page: page,
    pageSize: pageSize,
    filter: filter,
  );

  Future<PageResult<CatalogItem>> _items(
    String path, {
    required int page,
    required int pageSize,
    required CatalogQuery filter,
  }) async {
    if (!filter.isEmpty) {
      if (page > 1) return const PageResult(items: [], hasMore: false);
      final all = <CatalogItem>[];
      const scanSize = 50;
      for (var scanPage = 1; scanPage <= 100; scanPage++) {
        final raw = await _client.get(
          path,
          query: {'page': scanPage, 'pageSize': scanSize},
          cacheTtl: const Duration(minutes: 30),
          requiresAuth: false,
        );
        final maps = JsonHelpers.objectList(raw);
        all.addAll(maps.map(CatalogItem.fromJson));
        if (!JsonHelpers.hasMorePage(
          raw,
          page: scanPage,
          pageSize: scanSize,
          receivedCount: maps.length,
        )) {
          break;
        }
      }
      final ids = <String>{};
      final filtered = all
          .where((item) => item.matches(filter))
          .where((item) => ids.add(item.id))
          .toList();
      return PageResult(items: filtered, hasMore: false);
    }

    final raw = await _client.get(
      path,
      query: {'page': page, 'pageSize': pageSize},
      cacheTtl: const Duration(minutes: 30),
      requiresAuth: false,
    );
    final maps = JsonHelpers.objectList(raw);
    return PageResult(
      items: maps.map(CatalogItem.fromJson).toList(),
      hasMore: JsonHelpers.hasMorePage(
        raw,
        page: page,
        pageSize: pageSize,
        receivedCount: maps.length,
      ),
    );
  }

  Future<CatalogItem> _item(String path, {bool forceRefresh = false}) async {
    final raw = JsonHelpers.unwrap(
      await _client.get(
        path,
        cacheTtl: const Duration(hours: 6),
        forceRefresh: forceRefresh,
        requiresAuth: false,
      ),
    );
    if (raw is! Map) throw const ApiFailure('تعذر قراءة التفاصيل.');
    var item = CatalogItem.fromJson(Map<String, dynamic>.from(raw));
    if (item.typeId.isNotEmpty && item.typeName.isEmpty) {
      try {
        final lookupRaw = JsonHelpers.unwrap(
          await _client.get(
            item.isCase
                ? ApiPaths.caseCategory(item.typeId)
                : ApiPaths.campaignType(item.typeId),
            cacheTtl: const Duration(hours: 12),
            requiresAuth: false,
          ),
        );
        if (lookupRaw is Map) {
          final name = JsonHelpers.text(
            Map<String, dynamic>.from(lookupRaw),
            const ['name', 'title', 'description'],
          );
          if (name.isNotEmpty) item = item.copyWith(typeName: name);
        }
      } catch (_) {
        // تفاصيل العنصر الأساسية كافية حتى لو تعذر lookup الوصفي.
      }
    }
    return item;
  }
}
