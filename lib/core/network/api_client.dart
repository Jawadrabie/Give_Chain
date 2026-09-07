import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../cache/api_response_cache.dart';
import '../config/api_paths.dart';
import '../storage/token_storage.dart';
import 'api_failure.dart';

class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;
  static ApiClient? _instance;

  static void initialize() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiPaths.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = options.extra['requiresAuth'] != false;
          if (requiresAuth) {
            await TokenStorage.ensureValidSession();
            final token = TokenStorage.token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          options.headers.putIfAbsent(
            'X-Client-Name',
            () => 'GiveChain-Mobile',
          );
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await TokenStorage.clear();
          }
          handler.next(error);
        },
      ),
    );
    _instance = ApiClient._(dio);
  }

  /// Swaps the transport so a test can serve canned responses.
  ///
  /// Flutter's test binding fails every real HTTP request, so exercising any
  /// repository at all means replacing the adapter beneath Dio.
  @visibleForTesting
  set debugHttpAdapter(HttpClientAdapter adapter) =>
      _dio.httpClientAdapter = adapter;

  static ApiClient get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('ApiClient.initialize must be called before use.');
    }
    return value;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Duration? cacheTtl,
    bool forceRefresh = false,
    bool requiresAuth = true,
    int retryCount = 1,
  }) async {
    if (cacheTtl != null && !forceRefresh) {
      final cached = ApiResponseCache.read(path, query, maxAge: cacheTtl);
      if (cached != null) return cached;
    }

    ApiFailure? lastFailure;
    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final data = await request(
          'GET',
          path,
          query: query,
          headers: headers,
          requiresAuth: requiresAuth,
        );
        if (cacheTtl != null) {
          await ApiResponseCache.write(path, query, data);
        }
        return data;
      } on ApiFailure catch (failure) {
        lastFailure = failure;
        final retryable =
            failure.statusCode == null ||
            failure.statusCode == 408 ||
            failure.statusCode == 429 ||
            (failure.statusCode != null && failure.statusCode! >= 500);
        if (!retryable || attempt >= retryCount) break;
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    final failure = lastFailure ?? const ApiFailure('تعذر تنفيذ الطلب.');
    if (failure.statusCode == 401 || failure.statusCode == 403) throw failure;
    if (cacheTtl != null) {
      final cached = ApiResponseCache.read(
        path,
        query,
        maxAge: const Duration(days: 7),
      );
      if (cached != null) return cached;
    }
    throw failure;
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) => request(
    'POST',
    path,
    body: body,
    query: query,
    headers: headers,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) => request(
    'PUT',
    path,
    body: body,
    query: query,
    headers: headers,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) => request(
    'PATCH',
    path,
    body: body,
    query: query,
    headers: headers,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) => request(
    'DELETE',
    path,
    body: body,
    query: query,
    headers: headers,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    String? contentType,
    bool requiresAuth = true,
  }) async {
    if (requiresAuth && !await TokenStorage.ensureValidSession()) {
      throw const ApiFailure(
        'يجب تسجيل الدخول لإكمال هذه العملية.',
        statusCode: 401,
      );
    }
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          contentType: contentType,
          extra: {'requiresAuth': requiresAuth},
        ),
      );
      final data = response.statusCode == 204
          ? <String, dynamic>{}
          : ApiFailure.decodeMaybeJson(response.data);
      final applicationFailure = ApiFailure.fromPayload(
        data,
        statusCode: response.statusCode,
      );
      if (applicationFailure != null) throw applicationFailure;
      return data;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error);
    }
  }

  Future<dynamic> multipart(
    String method,
    String path, {
    required Map<String, dynamic> fields,
    String? filePath,
    List<String> filePaths = const [],
    String fileField = 'file',
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Iterable && value is! String) {
        for (final item in value) {
          if (item != null) {
            formData.fields.add(MapEntry(entry.key, item.toString()));
          }
        }
      } else {
        formData.fields.add(MapEntry(entry.key, value.toString()));
      }
    }

    final uploads = <String>{
      if (filePath != null && filePath.trim().isNotEmpty) filePath.trim(),
      ...filePaths
          .where((path) => path.trim().isNotEmpty)
          .map((path) => path.trim()),
    };
    for (final path in uploads) {
      final segments = path.replaceAll('\\', '/').split('/');
      formData.files.add(
        MapEntry(
          fileField,
          await MultipartFile.fromFile(
            path,
            filename: segments.isEmpty ? 'upload.bin' : segments.last,
          ),
        ),
      );
    }

    return request(
      method,
      path,
      body: formData,
      headers: headers,
      contentType: 'multipart/form-data',
      requiresAuth: requiresAuth,
    );
  }
}
