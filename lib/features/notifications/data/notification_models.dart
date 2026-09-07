import '../../../core/network/json_helpers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
  });
  final String id;
  final String title;
  final String body;
  final int type;
  final bool isRead;
  final String? referenceId;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: JsonHelpers.text(json, const ['id']),
        title: JsonHelpers.text(json, const ['title'], fallback: 'إشعار'),
        body: JsonHelpers.text(json, const ['body']),
        type: _int(json['type']) ?? 0,
        isRead: JsonHelpers.boolean(json, const ['isRead']),
        referenceId: _nullable(json['referenceId']),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    isRead: isRead ?? this.isRead,
    referenceId: referenceId,
    createdAt: createdAt,
  );
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}
