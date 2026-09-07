import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import '../../catalog/data/catalog_models.dart';
import 'complaint_models.dart';

class ComplaintRepository {
  const ComplaintRepository(this._client);
  final ApiClient _client;

  Future<Complaint> create(ComplaintRequest request) async {
    final raw = await _client.multipart(
      'POST',
      ApiPaths.complaints,
      fields: request.toFields(),
      filePaths: request.attachments,
      fileField: 'attachments',
    );
    final data = JsonHelpers.unwrap(raw);
    if (data is! Map) throw const ApiFailure('تعذر قراءة الشكوى بعد إنشائها.');
    return Complaint.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PageResult<Complaint>> mine({int page = 1, int pageSize = 20}) async {
    final raw = await _client.get(
      ApiPaths.complaints,
      query: {'page': page, 'pageSize': pageSize},
    );
    final items = JsonHelpers.objectList(raw).map(Complaint.fromJson).toList();
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

  Future<Complaint> detail(String id) async {
    final data = JsonHelpers.unwrap(await _client.get(ApiPaths.complaint(id)));
    if (data is! Map) throw const ApiFailure('تعذر قراءة تفاصيل الشكوى.');
    return Complaint.fromJson(Map<String, dynamic>.from(data));
  }
}
