abstract final class JsonHelpers {
  static const _listKeys = [
    'items',
    'results',
    'records',
    'list',
    'campaigns',
    'cases',
    'charities',
    'donations',
    'countries',
    'cities',
    'roles',
    'genders',
    'users',
    'benefitTypes',
    'benefits',
    'benefitRequests',
    'complaints',
    'notifications',
    'infoFields',
    'infoAnswers',
    'answers',
    'categories',
    'campaignTypes',
  ];

  static dynamic unwrap(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const ['data', 'result', 'value']) {
        if (map.containsKey(key) && map[key] != null) return map[key];
      }
    }
    return value;
  }

  static List<Map<String, dynamic>> objectList(dynamic value) {
    dynamic current = value;
    if (current is Map) {
      final root = Map<String, dynamic>.from(current);
      dynamic candidate = _firstList(root);
      final data = root['data'];
      if (candidate == null && data is List) {
        candidate = data;
      } else if (candidate == null && data is Map) {
        candidate = _firstList(Map<String, dynamic>.from(data));
      }
      final result = root['result'];
      if (candidate == null && result is List) {
        candidate = result;
      } else if (candidate == null && result is Map) {
        candidate = _firstList(Map<String, dynamic>.from(result));
      }
      current = candidate ?? current;
    }
    if (current is! List) return const [];
    return current
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static dynamic _firstList(Map<String, dynamic> map) {
    for (final key in _listKeys) {
      if (map[key] is List) return map[key];
    }
    return null;
  }

  static String text(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value is! Map && value is! Iterable) {
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return fallback;
  }

  static double number(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static bool boolean(
    Map<String, dynamic> json,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (const {'true', '1', 'yes', 'y'}.contains(normalized)) return true;
      if (const {'false', '0', 'no', 'n'}.contains(normalized)) return false;
    }
    return fallback;
  }

  static Map<String, dynamic> pageMap(dynamic value) {
    if (value is! Map) return const {};
    final root = Map<String, dynamic>.from(value);
    final data = root['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    final result = root['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return root;
  }

  static bool hasMorePage(
    dynamic value, {
    required int page,
    required int pageSize,
    required int receivedCount,
  }) {
    final map = pageMap(value);
    final totalPages = _toInt(map['totalPages']);
    if (totalPages != null) return page < totalPages;
    final totalCount = _toInt(map['totalCount']);
    if (totalCount != null) return page * pageSize < totalCount;
    final returnedPage = _toInt(map['page']);
    final returnedPageSize = _toInt(map['pageSize']);
    if (returnedPage != null && returnedPageSize != null) {
      return returnedPage * returnedPageSize <
          (totalCount ??
              returnedPage * returnedPageSize +
                  (receivedCount >= returnedPageSize ? 1 : 0));
    }
    return receivedCount >= pageSize;
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
