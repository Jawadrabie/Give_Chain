import 'dart:convert';

import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.statusCode,
    this.validationErrors = const [],
    this.code,
  });

  final String message;
  final int? statusCode;
  final List<String> validationErrors;
  final String? code;

  factory ApiFailure.fromDio(DioException exception) {
    final response = exception.response;
    final parsed = _decodeMaybeJson(response?.data);
    final payloadFailure = fromPayload(
      parsed,
      statusCode: response?.statusCode,
      fallback: null,
    );
    if (payloadFailure != null) return payloadFailure;

    final message = switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'انتهت مهلة الاتصال. حاول مرة أخرى.',
      DioExceptionType.connectionError =>
        'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.',
      DioExceptionType.cancel => 'تم إلغاء الطلب.',
      DioExceptionType.badCertificate => 'تعذر التحقق من شهادة الخادم.',
      _ => exception.message ?? 'حدث خطأ غير متوقع أثناء الاتصال بالخادم.',
    };

    return ApiFailure(message, statusCode: response?.statusCode);
  }

  /// Converts HTTP-200 application failures such as
  /// `{isSuccess:false, errors:[...]}` into a typed exception.
  /// Returns null when the payload represents success or has no error signal.
  static ApiFailure? fromPayload(
    dynamic raw, {
    int? statusCode,
    String? fallback,
  }) {
    final data = _decodeMaybeJson(raw);
    if (data is String && data.trim().isNotEmpty) {
      return fallback == null
          ? null
          : ApiFailure(data.trim(), statusCode: statusCode);
    }
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final successValue = map['isSuccess'] ?? map['success'] ?? map['succeeded'];
    final hasExplicitFailure =
        successValue == false ||
        successValue?.toString().trim().toLowerCase() == 'false';
    final status = map['statusCode'] ?? map['status'];
    final payloadStatus = status is num
        ? status.toInt()
        : int.tryParse(status?.toString() ?? '');
    final hasErrorStatus = payloadStatus != null && payloadStatus >= 400;
    if (!hasExplicitFailure && !hasErrorStatus) return null;

    final errors = _collectErrors(map['errors']);
    final message =
        _firstText(map, const [
          'message',
          'error',
          'title',
          'detail',
          'description',
        ]) ??
        (errors.isNotEmpty ? errors.first : fallback) ??
        'رفض الخادم الطلب.';
    final code = _firstText(map, const ['code', 'errorCode', 'type']);
    return ApiFailure(
      message,
      statusCode: statusCode ?? payloadStatus,
      validationErrors: errors.where((item) => item != message).toList(),
      code: code,
    );
  }

  static dynamic decodeMaybeJson(dynamic value) => _decodeMaybeJson(value);

  static dynamic _decodeMaybeJson(dynamic value) {
    if (value is! String) return value;
    final text = value.trim();
    if (text.isEmpty) return text;
    if (!(text.startsWith('{') || text.startsWith('['))) return text;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  static List<String> _collectErrors(dynamic value) {
    final result = <String>[];
    void add(dynamic item) {
      if (item == null) return;
      if (item is Map) {
        for (final entry in item.entries) {
          final before = result.length;
          add(entry.value);
          if (result.length == before && entry.value != null) {
            result.add('${entry.key}: ${entry.value}');
          }
        }
        return;
      }
      if (item is Iterable) {
        for (final nested in item) {
          add(nested);
        }
        return;
      }
      final text = item.toString().trim();
      if (text.isNotEmpty && !result.contains(text)) result.add(text);
    }

    add(value);
    return result;
  }

  static String? _firstText(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value is! Map && value is! Iterable) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  @override
  String toString() => validationErrors.isEmpty
      ? message
      : '$message\n${validationErrors.join('\n')}';
}
