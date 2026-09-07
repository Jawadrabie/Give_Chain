import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';

class MediaFile {
  const MediaFile({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.url,
    required this.mediaType,
    required this.isPrimary,
    required this.uploadedAt,
  });

  final String id;
  final int ownerType;
  final String ownerId;
  final String url;
  final int mediaType;
  final bool isPrimary;
  final DateTime uploadedAt;

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
    id: JsonHelpers.text(json, const ['id']),
    ownerType: _int(json['ownerType']) ?? 0,
    ownerId: JsonHelpers.text(json, const ['ownerId']),
    url: JsonHelpers.text(json, const ['url']),
    mediaType: _int(json['mediaType']) ?? 0,
    isPrimary: JsonHelpers.boolean(json, const ['isPrimary']),
    uploadedAt:
        DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
        DateTime.now().toUtc(),
  );
}

class MediaRepository {
  const MediaRepository(this._client);
  final ApiClient _client;

  Future<List<MediaFile>> byOwner({
    required int ownerType,
    required String ownerId,
  }) async {
    final raw = await _client.get(
      ApiPaths.media,
      query: {'ownerType': ownerType, 'ownerId': ownerId},
      requiresAuth: false,
      cacheTtl: const Duration(minutes: 15),
    );
    return JsonHelpers.objectList(raw).map(MediaFile.fromJson).toList();
  }

  Future<List<MediaFile>> upload({
    required int ownerType,
    required String ownerId,
    required List<String> files,
  }) async {
    if (files.isEmpty) return const [];
    final raw = await _client.multipart(
      'POST',
      ApiPaths.media,
      fields: {'ownerType': ownerType, 'ownerId': ownerId},
      filePaths: files,
      fileField: 'files',
      requiresAuth: true,
    );
    final items = JsonHelpers.objectList(raw);
    if (items.isNotEmpty) return items.map(MediaFile.fromJson).toList();
    final data = JsonHelpers.unwrap(raw);
    if (data is Map) {
      return [MediaFile.fromJson(Map<String, dynamic>.from(data))];
    }
    throw const ApiFailure('تم رفع الملفات لكن تعذر قراءة استجابة الوسائط.');
  }

  Future<void> delete(String id) => _client.delete(ApiPaths.mediaDelete(id));
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
